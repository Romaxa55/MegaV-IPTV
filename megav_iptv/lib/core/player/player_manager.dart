import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'decoder_config.dart';
import 'media_kit_engine.dart';
import 'native_video_player_engine.dart';
import 'media3_engine.dart';
import 'player_engine.dart';

class PlayerManager {
  PlayerEngine? _activeEngine;
  Media3Engine? _media3Engine;
  DecoderConfig _config;

  final _stateController = StreamController<PlayerState>.broadcast();
  final _errorController = StreamController<String?>.broadcast();

  StreamSubscription? _stateSub;
  StreamSubscription? _errorSub;
  Timer? _markWorkingTimer;

  String? _currentUrl;
  String? _currentChannelId;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const String _decoderPrefsPrefix = 'decoder_';

  PlayerManager({DecoderConfig? config}) : _config = config ?? const DecoderConfig();

  Stream<PlayerState> get stateStream => _stateController.stream;
  Stream<String?> get errorStream => _errorController.stream;
  PlayerEngine? get activeEngine => _activeEngine;
  Media3Engine? get media3Engine => _media3Engine;
  DecoderConfig get config => _config;
  bool get usesMedia3 => _config.usesMedia3;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _activeEngine = MediaKitEngine(config: _config);
    } else if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      _activeEngine = NativeVideoPlayerEngine();
    } else {
      _activeEngine = MediaKitEngine(config: _config);
    }

    await _activeEngine!.initialize();
    _media3Engine = Media3Engine();
    _listenToActiveEngine();
    _isInitialized = true;
  }

  void _listenToActiveEngine() {
    _stateSub?.cancel();
    _errorSub?.cancel();

    _stateSub = _activeEngine!.stateStream.listen((state) {
      _stateController.add(state);
      if (state == PlayerState.playing) {
        _scheduleMarkWorking();
      } else {
        _markWorkingTimer?.cancel();
      }
    });

    _errorSub = _activeEngine!.errorStream.listen((error) {
      debugPrint('PlayerManager: Error — $error');
      _errorController.add(error);
      _handleError();
    });
  }

  void _scheduleMarkWorking() {
    _markWorkingTimer?.cancel();
    _markWorkingTimer = Timer(const Duration(seconds: 3), () {
      markCurrentDecoderWorking();
    });
  }

  Future<void> _handleError() async {
    if (_currentUrl == null) return;
    _retryCount++;

    if (_retryCount <= _maxRetries) {
      debugPrint('PlayerManager: Retry $_retryCount/$_maxRetries');
      await Future.delayed(const Duration(seconds: 1));

      if (_retryCount == 2 && _config.decoderMode != DecoderMode.software) {
        debugPrint('PlayerManager: Falling back to software decoder');
        _config = _config.copyWith(decoderMode: DecoderMode.software);
        if (_activeEngine is MediaKitEngine) {
          await (_activeEngine as MediaKitEngine).updateConfig(_config);
        }
      }

      await _activeEngine!.open(_currentUrl!);
    } else {
      debugPrint('PlayerManager: Max retries reached');
    }
  }

  /// Load saved decoder for a channel, or null if none saved.
  Future<DecoderMode?> _loadSavedDecoder(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('$_decoderPrefsPrefix$channelId');
    if (saved == null) return null;
    try {
      return DecoderMode.values.firstWhere((m) => m.name == saved);
    } catch (_) {
      return null;
    }
  }

  /// Save the working decoder for a channel.
  Future<void> _saveWorkingDecoder(String channelId, DecoderMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_decoderPrefsPrefix$channelId', mode.name);
    debugPrint('PlayerManager: Saved decoder ${mode.name} for channel $channelId');
  }

  /// Play a channel via the active engine.
  Future<void> playChannel(String url, {String? channelId}) async {
    _retryCount = 0;
    _currentUrl = url;
    _currentChannelId = channelId;

    if (channelId != null && _config.decoderMode == DecoderMode.auto) {
      final saved = await _loadSavedDecoder(channelId);
      if (saved != null && saved != _config.decoderMode) {
        debugPrint('PlayerManager: Using saved decoder ${saved.name} for $channelId');
        _config = _config.copyWith(decoderMode: saved);
        if (_activeEngine is MediaKitEngine) {
          await (_activeEngine as MediaKitEngine).updateConfig(_config);
        }
      }
    }

    await _activeEngine?.open(url);
  }

  /// Mark current channel+decoder as working (call after successful playback).
  Future<void> markCurrentDecoderWorking() async {
    if (_currentChannelId != null) {
      await _saveWorkingDecoder(_currentChannelId!, _config.decoderMode);
    }
  }

  Future<void> stop() async {
    _currentUrl = null;
    _currentChannelId = null;
    await _activeEngine?.stop();
  }

  Future<void> setVolume(double volume) async {
    await _activeEngine?.setVolume(volume);
  }

  Future<void> updateDecoderConfig(DecoderConfig config) async {
    _config = config;
    if (!config.usesMedia3) {
      if (_activeEngine is MediaKitEngine) {
        await (_activeEngine as MediaKitEngine).updateConfig(config);
      }
    }
  }

  Future<void> dispose() async {
    _markWorkingTimer?.cancel();
    await _stateSub?.cancel();
    await _errorSub?.cancel();
    await _activeEngine?.dispose();
    _media3Engine?.dispose();
    await _stateController.close();
    await _errorController.close();
  }
}
