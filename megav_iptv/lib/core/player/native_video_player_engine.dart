import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import 'player_engine.dart';

class NativeVideoPlayerEngine implements PlayerEngine {
  VideoPlayerController? _controller;

  final _stateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _errorController = StreamController<String?>.broadcast();

  PlayerState _currentState = PlayerState.idle;

  @override
  Stream<PlayerState> get stateStream => _stateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<String?> get errorStream => _errorController.stream;

  @override
  PlayerState get currentState => _currentState;

  @override
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  void _updateState(PlayerState state) {
    if (_currentState != state) {
      _currentState = state;
      _stateController.add(state);
    }
  }

  @override
  Future<void> initialize() async {
    // Initialization is deferred until open()
  }

  @override
  Future<void> open(String url) async {
    _updateState(PlayerState.loading);
    try {
      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: {'User-Agent': 'MegaV-IPTV/1.0'});

      _controller!.addListener(_videoListener);

      await _controller!.initialize();
      if (_controller!.value.hasError) {
        throw _controller!.value.errorDescription ?? 'Unknown error';
      }

      await _controller!.play();
      _updateState(PlayerState.playing);
    } catch (e) {
      debugPrint('NativeVideoPlayerEngine error: $e');
      _errorController.add(e.toString());
      _updateState(PlayerState.error);
    }
  }

  void _videoListener() {
    if (_controller == null) return;

    final value = _controller!.value;

    if (value.hasError) {
      _errorController.add(value.errorDescription);
      _updateState(PlayerState.error);
      return;
    }

    if (value.isInitialized) {
      if (value.isBuffering) {
        _updateState(PlayerState.loading);
      } else if (value.isPlaying) {
        _updateState(PlayerState.playing);
      } else if (!value.isPlaying && value.position >= value.duration) {
        _updateState(PlayerState.stopped);
      } else {
        _updateState(PlayerState.paused);
      }

      _positionController.add(value.position);
    }
  }

  @override
  Future<void> play() async {
    await _controller?.play();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> stop() async {
    await _controller?.pause();
    await _controller?.seekTo(Duration.zero);
    _updateState(PlayerState.stopped);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _controller?.setVolume(volume);
  }

  @override
  Future<void> dispose() async {
    if (_controller != null) {
      _controller!.removeListener(_videoListener);
      await _controller!.dispose();
      _controller = null;
    }
    await _stateController.close();
    await _positionController.close();
    await _errorController.close();
  }

  @override
  Widget buildVideoWidget({BoxFit fit = BoxFit.contain, double? width, double? height}) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final size = _controller!.value.size;
    if (size.width == 0 || size.height == 0) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: FittedBox(
          fit: fit,
          child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(_controller!)),
        ),
      ),
    );
  }
}
