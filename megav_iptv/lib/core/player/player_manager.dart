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
  // player-cinematic-redux (Wave 6, GH Issue #3): permanent error
  // budget. Сетевые DNS/TCP ошибки не учитываются здесь — для них
  // запущен бесконечный retry с exponential backoff.
  static const int _maxPermanentRetries = 5;
  // Network-class retries — unlimited, capped backoff.
  static const Duration _backoffInitial = Duration(seconds: 1);
  static const Duration _backoffMax = Duration(seconds: 60);
  // Cancel token: новый playChannel/stop увеличивает этот ID, и
  // зависший retry-loop проверяет его перед re-open, чтобы старый
  // URL не возобновился поверх нового.
  int _playToken = 0;
  bool _hwFallbackApplied = false;

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
      _handleError(error);
    });
  }

  void _scheduleMarkWorking() {
    _markWorkingTimer?.cancel();
    // No longer saving per-channel decoder
  }

  /// Classify an engine error string so we can pick the right retry
  /// policy. Network-class errors (DNS/TCP/timeout/unreachable) get
  /// unlimited retries with exponential backoff (юзер просто потерял
  /// сеть на минуту и не должен вручную перезапускать канал). Other
  /// errors (404/403/codec/format) are treated as permanent and
  /// retried only [_maxPermanentRetries] times before stopping.
  bool _isNetworkError(String? err) {
    if (err == null) return false;
    final s = err.toLowerCase();
    return s.contains('failed to resolve hostname') ||
        s.contains('dns') ||
        s.contains('tcp:') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('network is unreachable') ||
        s.contains('host is unreachable') ||
        s.contains('no route to host') ||
        s.contains('timed out') ||
        s.contains('timeout') ||
        s.contains('socket') ||
        s.contains('operation now in progress');
  }

  /// Exponential backoff (1s → 2 → 4 → 8 → 16 → 32 → 60 cap).
  Duration _backoffFor(int attempt) {
    final ms = _backoffInitial.inMilliseconds * (1 << (attempt - 1).clamp(0, 6));
    return Duration(milliseconds: ms.clamp(0, _backoffMax.inMilliseconds));
  }

  Future<void> _handleError([String? lastError]) async {
    if (_currentUrl == null) return;
    final token = _playToken;
    _retryCount++;

    final isNetwork = _isNetworkError(lastError);

    // Permanent error budget cap.
    if (!isNetwork && _retryCount > _maxPermanentRetries) {
      debugPrint('PlayerManager: Permanent error budget exhausted ($_retryCount attempts)');
      return;
    }

    // HW→SW decoder fallback на 2-й попытке — оставлено как было,
    // помогает при codec-incompatibility на rtd2851a и тоже не
    // конфликтует с network class.
    if (_retryCount == 2 && !_hwFallbackApplied && _config.decoderMode != DecoderMode.software) {
      debugPrint('PlayerManager: Falling back to software decoder');
      _hwFallbackApplied = true;
      _config = _config.copyWith(decoderMode: DecoderMode.software);
      if (_activeEngine is MediaKitEngine) {
        await (_activeEngine as MediaKitEngine).updateConfig(_config);
      }
    }

    final delay = _backoffFor(_retryCount);
    debugPrint(
      'PlayerManager: Retry #$_retryCount '
      '(${isNetwork ? "network/backoff ${delay.inSeconds}s" : "permanent budget $_retryCount/$_maxPermanentRetries"})',
    );
    await Future.delayed(delay);

    // Cancel guard — пользователь мог запустить другой канал или
    // вызвать stop() пока мы спали в backoff.
    if (!_isInitialized || _currentUrl == null || _playToken != token) {
      debugPrint('PlayerManager: Retry cancelled (token changed)');
      return;
    }

    await _activeEngine!.open(_currentUrl!);
  }

  Future<void> playChannel(String url, {String? channelId}) async {
    // Bump token — любой in-flight backoff из предыдущего channel
    // больше не reopen-ится (см. _handleError).
    _playToken++;
    _retryCount = 0;
    _hwFallbackApplied = false;
    _currentUrl = url;

    await _activeEngine?.open(url);
  }

  Future<void> stop() async {
    _playToken++;
    _currentUrl = null;
    _retryCount = 0;
    _hwFallbackApplied = false;
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
