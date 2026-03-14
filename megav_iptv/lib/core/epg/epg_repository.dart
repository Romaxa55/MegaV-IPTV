import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../playlist/models/epg_program.dart';
import 'epg_database.dart';
import 'xmltv_parser.dart';

class EpgRepository {
  final EpgDatabase _db = EpgDatabase();
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  EpgDatabase get database => _db;

  String sourceUrl = 'https://iptvx.one/epg/epg.xml.gz';
  static const _refreshInterval = Duration(hours: 6);

  void startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());
  }

  /// Returns the path where the EPG file is cached on disk.
  Future<String> get _epgFilePath async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, 'epg_cache.xml.gz');
  }

  Future<void> refresh({bool force = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      if (!force) {
        final lastUpdated = await _db.getLastUpdated();
        if (lastUpdated != null) {
          final elapsed = DateTime.now().difference(lastUpdated);
          if (elapsed < _refreshInterval) {
            debugPrint('EPG: Skipping refresh, last update ${elapsed.inMinutes}m ago');
            return;
          }
        }
      }

      final filePath = await _epgFilePath;

      // --- Step 1: Stream download to file (no RAM buffering) ---
      debugPrint('EPG: Downloading from $sourceUrl to disk...');
      final stopwatch = Stopwatch()..start();

      final request = http.Request('GET', Uri.parse(sourceUrl));
      final streamedResponse = await request.send();
      if (streamedResponse.statusCode != 200) {
        throw Exception('EPG download failed: ${streamedResponse.statusCode}');
      }

      final file = File(filePath);
      final sink = file.openWrite();
      int downloadedBytes = 0;
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
      }
      await sink.flush();
      await sink.close();

      final downloadMb = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
      debugPrint('EPG: Downloaded $downloadMb MB in ${stopwatch.elapsedMilliseconds}ms');

      // --- Step 2: Soft-delete existing records ---
      await _db.markAllDeleted();

      // --- Step 3: Stream-parse from file, inserting into DB in chunks ---
      debugPrint('EPG: Parsing from file (streaming)...');
      stopwatch.reset();

      final counts = await parseXmltvFromFile(
        filePath,
        onChannels: (channels) async {
          await _db.upsertChannels(channels);
          debugPrint('EPG: Inserted ${channels.length} channels');
        },
        onNameMappings: (mappings) async {
          await _db.insertNameMappings(mappings);
          final totalNames = mappings.values.fold<int>(0, (s, l) => s + l.length);
          debugPrint('EPG: Inserted $totalNames name mappings for ${mappings.length} channels');
        },
        onProgramBatch: (batch) async {
          await _db.insertProgramsBatch(batch);
        },
        batchSize: 1000,
      );

      debugPrint(
        'EPG: Parsed ${counts.channels} channels, ${counts.programs} programs '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );

      // --- Step 4: Cleanup ---
      await _db.purgeDeleted();
      await _db.clearOldPrograms();
      await _db.setLastUpdated(DateTime.now());

      final dbCounts = await _db.getCounts();
      debugPrint(
        'EPG: Done — ${dbCounts.channels} channels, '
        '${dbCounts.programs} programs in DB',
      );
    } catch (e, st) {
      debugPrint('EPG: Refresh error: $e\n$st');
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<EpgProgram?> getCurrentProgram(String channelId) {
    return _db.getCurrentProgram(channelId);
  }

  Future<EpgProgram?> getNextProgram(String channelId) {
    return _db.getNextProgram(channelId);
  }

  Future<List<EpgProgram>> getProgramsForChannel(String channelId, {DateTime? from, DateTime? to}) {
    return _db.getProgramsForChannel(channelId, from: from, to: to);
  }

  Future<String?> resolveChannelId({String? tvgId, String? channelName}) {
    return _db.resolveChannelId(tvgId: tvgId, channelName: channelName);
  }

  Future<List<EpgProgram>> searchPrograms(String query, {int limit = 50}) {
    return _db.searchPrograms(query, limit: limit);
  }

  Future<DateTime?> getLastUpdated() => _db.getLastUpdated();

  Future<({int channels, int programs})> getCounts() => _db.getCounts();

  Future<void> dispose() async {
    _refreshTimer?.cancel();
    await _db.close();
  }
}
