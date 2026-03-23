import 'package:flutter/widgets.dart';

/// Detects if the user is rapidly changing focus (e.g. holding down the D-pad).
/// This can be used to disable heavy animations (scale, blur) during fast scrolling
/// to prevent visual lag on low-end TVs.
class FastScrollDetector {
  static final FastScrollDetector _instance = FastScrollDetector._internal();
  factory FastScrollDetector() => _instance;
  FastScrollDetector._internal();

  DateTime _lastEventTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isFastScrolling = false;

  /// Threshold in milliseconds. If focus events happen faster than this,
  /// we consider it a fast scroll.
  /// 150ms is slightly shorter than a typical 200ms animation, meaning
  /// if a new event arrives before the old animation finishes, we trigger fast mode.
  static const int _thresholdMs = 150;

  /// Notify that a navigation/focus event occurred.
  /// Returns [true] if this event is considered part of a "fast scroll" sequence.
  bool onEvent() {
    final now = DateTime.now();
    final diff = now.difference(_lastEventTime).inMilliseconds;
    _lastEventTime = now;

    if (diff < _thresholdMs) {
      _isFastScrolling = true;
    } else {
      // User paused, reset state
      _isFastScrolling = false;
    }

    return _isFastScrolling;
  }

  /// Returns the current state without triggering an event timestamp update.
  bool get isFastScrolling => _isFastScrolling;
}

/// Helper extension to easily check if we should skip animations in this frame
extension FastScrollContextExtension on BuildContext {
  bool get isFastScrolling => FastScrollDetector().isFastScrolling;
}
