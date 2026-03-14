import 'package:flutter/widgets.dart';

enum PlayerState { idle, loading, playing, paused, error, stopped }

abstract class PlayerEngine {
  Stream<PlayerState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<String?> get errorStream;

  PlayerState get currentState;
  bool get isPlaying;

  Future<void> initialize();
  Future<void> open(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> dispose();

  Widget buildVideoWidget({BoxFit fit = BoxFit.contain, double? width, double? height});
}
