import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import 'decoder_config.dart';
import 'player_engine.dart';

class MediaKitEngine extends PlayerEngine {
  late final Player _player;
  late final VideoController _videoController;

  final DecoderConfig config;

  final _stateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _errorController = StreamController<String?>.broadcast();

  PlayerState _currentState = PlayerState.idle;
  StreamSubscription? _playingSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _positionSub;

  MediaKitEngine({this.config = const DecoderConfig()});

  @override
  Stream<PlayerState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<String?> get errorStream => _errorController.stream;

  @override
  PlayerState get currentState => _currentState;

  @override
  bool get isPlaying => _currentState == PlayerState.playing;

  VideoController get videoController => _videoController;

  void _setState(PlayerState state) {
    _currentState = state;
    _stateController.add(state);
  }

  @override
  Future<void> initialize() async {
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 2 * 1024 * 1024,
      ),
    );

    _videoController = VideoController(_player);

    await _applyMpvProperties();

    _playingSub = _player.stream.playing.listen((playing) {
      if (playing) {
        _setState(PlayerState.playing);
      } else if (_currentState == PlayerState.playing) {
        _setState(PlayerState.paused);
      }
    });

    _errorSub = _player.stream.error.listen((error) {
      if (error.isNotEmpty) {
        _setState(PlayerState.error);
        _errorController.add(error);
      }
    });

    _positionSub = _player.stream.position.listen((position) {
      _positionController.add(position);
    });
  }

  Future<void> _applyMpvProperties() async {
    if (_player.platform is NativePlayer) {
      final np = _player.platform as NativePlayer;
      for (final entry in config.mpvProperties.entries) {
        await np.setProperty(entry.key, entry.value);
      }
    }
  }

  Future<void> updateConfig(DecoderConfig newConfig) async {
    if (_player.platform is NativePlayer) {
      final np = _player.platform as NativePlayer;
      for (final entry in newConfig.mpvProperties.entries) {
        await np.setProperty(entry.key, entry.value);
      }
    }
  }

  @override
  Future<void> open(String url) async {
    _setState(PlayerState.loading);
    try {
      await _player.open(Media(url));
    } catch (e) {
      _setState(PlayerState.error);
      _errorController.add(e.toString());
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _setState(PlayerState.stopped);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume * 100);
  }

  @override
  Future<void> dispose() async {
    await _playingSub?.cancel();
    await _errorSub?.cancel();
    await _positionSub?.cancel();
    await _player.dispose();
    await _stateController.close();
    await _positionController.close();
    await _errorController.close();
  }

  @override
  Widget buildVideoWidget({
    BoxFit fit = BoxFit.contain,
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Video(
        controller: _videoController,
        fit: fit,
      ),
    );
  }
}
