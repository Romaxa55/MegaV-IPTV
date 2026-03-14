import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../epg/epg_database.dart';
import '../playlist/models/channel.dart';

/// Lazy, queue-based thumbnail service.
///
/// Priority chain for each channel:
/// 1. EPG channel icon (picon URL from XMLTV — fast, no decode)
/// 2. Disk-cached snapshot (previously captured frame)
/// 3. Live snapshot via media_kit (open stream → grab 1 frame → close)
///
/// Constraints:
/// - Max 1 concurrent stream snapshot to avoid overload
/// - Disk cache with 30-min TTL
/// - Visible-first ordering (LIFO queue)
class ThumbnailService {
  final EpgDatabase _epgDb;

  static const _snapshotTtl = Duration(minutes: 30);
  static const _streamOpenTimeout = Duration(seconds: 8);
  static const _maxRetries = 1;

  String? _cacheDir;
  final _pendingQueue = <_ThumbnailRequest>[];
  bool _isProcessing = false;

  /// In-memory cache: channel URL hash → resolved image path or URL
  final _cache = <int, ThumbnailResult>{};

  ThumbnailService({required EpgDatabase epgDb}) : _epgDb = epgDb;

  Future<String> get _cacheDirPath async {
    if (_cacheDir != null) return _cacheDir!;
    final dbPath = await getDatabasesPath();
    final dir = p.join(dbPath, 'thumbnails');
    await Directory(dir).create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  /// Get thumbnail for a channel.
  /// Returns immediately with whatever is available (may be null initially).
  /// Triggers background loading if needed.
  ThumbnailResult? getThumbnail(Channel channel) {
    final key = channel.hashCode;

    if (_cache.containsKey(key)) return _cache[key];

    // Queue for background resolution
    _enqueue(channel);
    return null;
  }

  /// Request thumbnail and get a Future that completes when resolved.
  Future<ThumbnailResult?> requestThumbnail(Channel channel) async {
    final key = channel.hashCode;
    if (_cache.containsKey(key)) return _cache[key];

    final completer = Completer<ThumbnailResult?>();
    _enqueue(channel, completer: completer);
    return completer.future;
  }

  void _enqueue(Channel channel, {Completer<ThumbnailResult?>? completer}) {
    final key = channel.hashCode;

    // Don't duplicate
    final existing = _pendingQueue.indexWhere((r) => r.key == key);
    if (existing >= 0) {
      if (completer != null) {
        _pendingQueue[existing].completers.add(completer);
      }
      // Move to front (LIFO — visible items get priority)
      final req = _pendingQueue.removeAt(existing);
      _pendingQueue.add(req);
      return;
    }

    _pendingQueue.add(_ThumbnailRequest(key: key, channel: channel, completers: completer != null ? [completer] : []));

    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_pendingQueue.isNotEmpty) {
        // LIFO: take from end (most recently requested = most likely visible)
        final request = _pendingQueue.removeLast();
        final result = await _resolve(request.channel);
        if (result != null) {
          _cache[request.key] = result;
        }
        for (final c in request.completers) {
          c.complete(result);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<ThumbnailResult?> _resolve(Channel channel) async {
    // 1. Try EPG channel icon (picon)
    final epgIcon = await _getEpgChannelIcon(channel);
    if (epgIcon != null) {
      return ThumbnailResult(url: epgIcon, type: ThumbnailType.epgIcon);
    }

    // 2. Channel logo from M3U
    if (channel.logoUrl != null && channel.logoUrl!.isNotEmpty) {
      return ThumbnailResult(url: channel.logoUrl!, type: ThumbnailType.logo);
    }

    // 3. Check disk cache
    final cached = await _getDiskCached(channel);
    if (cached != null) {
      return ThumbnailResult(filePath: cached, type: ThumbnailType.snapshot);
    }

    // 4. Live snapshot from stream
    final snapshot = await _captureSnapshot(channel);
    if (snapshot != null) {
      return ThumbnailResult(filePath: snapshot, type: ThumbnailType.snapshot);
    }

    return null;
  }

  Future<String?> _getEpgChannelIcon(Channel channel) async {
    try {
      final resolvedId = await _epgDb.resolveChannelId(tvgId: channel.tvgId, channelName: channel.name);
      if (resolvedId == null) return null;
      final epgChannel = await _epgDb.getChannel(resolvedId);
      if (epgChannel?.icon != null && epgChannel!.icon!.isNotEmpty) {
        return epgChannel.icon;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _getDiskCached(Channel channel) async {
    final dir = await _cacheDirPath;
    final file = File(p.join(dir, '${channel.hashCode}.jpg'));
    if (!await file.exists()) return null;

    final stat = await file.stat();
    if (DateTime.now().difference(stat.modified) > _snapshotTtl) {
      await file.delete();
      return null;
    }

    return file.path;
  }

  Future<String?> _captureSnapshot(Channel channel) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await _doCapture(channel);
      } catch (e) {
        debugPrint('Thumbnail: snapshot attempt $attempt failed for ${channel.name}: $e');
      }
    }
    return null;
  }

  Future<String?> _doCapture(Channel channel) async {
    final player = Player(
      configuration: const PlayerConfiguration(bufferSize: 512 * 1024, logLevel: MPVLogLevel.warn),
    );
    // ignore: unused_local_variable
    final controller = VideoController(player); // must exist for screenshot()

    try {
      if (player.platform is NativePlayer) {
        final np = player.platform as NativePlayer;
        await np.setProperty('demuxer-lavf-o', 'fflags=+nobuffer');
        await np.setProperty('framedrop', 'vo');
        await np.setProperty('video-sync', 'audio');
        await np.setProperty('audio', 'no');
        await np.setProperty('pause', 'yes');
      }

      await player.open(Media(channel.url), play: true);

      // Wait for first frame or timeout
      final gotFrame = await player.stream.videoParams
          .where((vp) => vp.w != null && vp.w! > 0)
          .first
          .timeout(_streamOpenTimeout, onTimeout: () => const VideoParams());

      if (gotFrame.w == null || gotFrame.w! <= 0) {
        return null;
      }

      // Small delay to let at least one full frame decode
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final Uint8List? screenshot = await player.screenshot(format: 'image/jpeg');
      if (screenshot == null || screenshot.isEmpty) return null;

      final dir = await _cacheDirPath;
      final file = File(p.join(dir, '${channel.hashCode}.jpg'));
      await file.writeAsBytes(screenshot);

      return file.path;
    } finally {
      await player.dispose();
    }
  }

  /// Invalidate cache for a channel (e.g. after EPG refresh).
  void invalidate(Channel channel) {
    _cache.remove(channel.hashCode);
  }

  /// Clear all in-memory and disk caches.
  Future<void> clearAll() async {
    _cache.clear();
    _pendingQueue.clear();
    final dir = await _cacheDirPath;
    final directory = Directory(dir);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      await directory.create();
    }
  }

  void dispose() {
    _pendingQueue.clear();
    _cache.clear();
  }
}

enum ThumbnailType { epgIcon, logo, snapshot }

class ThumbnailResult {
  final String? url;
  final String? filePath;
  final ThumbnailType type;

  const ThumbnailResult({this.url, this.filePath, required this.type});

  /// Whether this is a network URL (EPG icon or logo) vs local file.
  bool get isNetwork => url != null;
  bool get isFile => filePath != null;
}

class _ThumbnailRequest {
  final int key;
  final Channel channel;
  final List<Completer<ThumbnailResult?>> completers;

  _ThumbnailRequest({required this.key, required this.channel, required this.completers});
}
