import 'dart:async';
import 'package:flutter/foundation.dart';

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
  int _retryCount = 0;
  static const int _maxRetries = 3;

  PlayerManager({DecoderConfig? config}) : _config = config ?? const DecoderConfig();

  Stream<PlayerState> get stateStream => _stateController.stream;
  Stream<String?> get errorStream => _errorController.stream;
  PlayerEngine? get activeEngine => _activeEngine;
  Media3Engine? get media3Engine => _media3Engine;
  DecoderConfig get config => _config;
  bool get usesMedia3 => _config.usesMedia3;
  String? get currentUrl => _currentUrl;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _activeEngine = MediaKitEngine(config: _config);
    } else if (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS) {
      _activeEngine = NativeVideoPlayerEngine();
    } else {
      // Для Android, Windows, Linux оставляем MediaKit — он лучше справляется с TS/IPTV стримами
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
    // No longer saving per-channel decoder
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

  Future<void> playChannel(String url, {String? channelId}) async {
    _retryCount = 0;
    _currentUrl = url;

    await _activeEngine?.open(url);
  }

  Future<void> stop() async {
    _currentUrl = null;
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
