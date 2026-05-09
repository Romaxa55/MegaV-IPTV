import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Snapshot of runtime performance metrics aggregated from
/// [WidgetsBinding.addTimingsCallback].
///
/// Designed as a value type so it can flow through [StreamProvider]
/// efficiently — equality skips redundant rebuilds when consecutive
/// frames produce identical readings (Req 7.2, 7.3, 7.4).
@immutable
class PerfMetrics {
  const PerfMetrics({required this.fps, required this.skippedFrames, this.memoryBytes, this.bufferSeconds});

  /// Average FPS computed from the rolling 60-frame window.
  final double fps;

  /// Number of frames in the rolling window whose total span exceeded
  /// 16.7 ms (16700 µs) — the 60 FPS budget.
  final int skippedFrames;

  /// Process maxRss in bytes, or `null` on platforms where
  /// [ProcessInfo.maxRss] is unavailable / throws.
  final int? memoryBytes;

  /// Player buffer fill in seconds. Always `null` until the player layer
  /// exports a source overridable via [ProviderScope] (Open Question 2).
  final double? bufferSeconds;

  @override
  bool operator ==(Object other) =>
      other is PerfMetrics &&
      other.fps == fps &&
      other.skippedFrames == skippedFrames &&
      other.memoryBytes == memoryBytes &&
      other.bufferSeconds == bufferSeconds;

  @override
  int get hashCode => Object.hash(fps, skippedFrames, memoryBytes, bufferSeconds);
}

/// Streams [PerfMetrics] aggregated from [WidgetsBinding.addTimingsCallback].
///
/// Auto-disposes the timing callback when the last listener detaches so
/// the provider has zero overhead when the Settings screen is closed.
///
/// Window: rolling 60 frames, FPS = `1e6 / avg(totalSpan µs)`. Skipped
/// frames count those whose total span exceeded 16.7 ms.
final perfMetricsProvider = StreamProvider.autoDispose<PerfMetrics>((ref) {
  final controller = StreamController<PerfMetrics>();
  final history = <FrameTiming>[];
  const windowSize = 60;

  void onTimings(List<FrameTiming> timings) {
    history.addAll(timings);
    if (history.length > windowSize) {
      history.removeRange(0, history.length - windowSize);
    }
    if (history.isEmpty) return;

    final totalMicros = history.map((t) => t.totalSpan.inMicroseconds).reduce((a, b) => a + b);
    final avgMicros = totalMicros / history.length;
    final fps = avgMicros > 0 ? (1e6 / avgMicros) : 0.0;
    final skipped = history.where((t) => t.totalSpan.inMicroseconds > 16700).length;

    int? memBytes;
    try {
      memBytes = ProcessInfo.maxRss;
    } catch (_) {
      memBytes = null;
    }

    if (!controller.isClosed) {
      controller.add(PerfMetrics(fps: fps, skippedFrames: skipped, memoryBytes: memBytes, bufferSeconds: null));
    }
  }

  WidgetsBinding.instance.addTimingsCallback(onTimings);
  ref.onDispose(() {
    WidgetsBinding.instance.removeTimingsCallback(onTimings);
    controller.close();
  });

  return controller.stream;
});
