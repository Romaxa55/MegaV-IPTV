import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/perf/perf_metrics_provider.dart';

void main() {
  test('PerfMetrics equality and hashCode are symmetric', () {
    const a = PerfMetrics(fps: 60.0, skippedFrames: 0, memoryBytes: 1000, bufferSeconds: 5.0);
    const b = PerfMetrics(fps: 60.0, skippedFrames: 0, memoryBytes: 1000, bufferSeconds: 5.0);
    const c = PerfMetrics(fps: 30.0, skippedFrames: 5, memoryBytes: 1000, bufferSeconds: 5.0);

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });

  test('PerfMetrics const constructor leaves nullable fields null by default', () {
    const metrics = PerfMetrics(fps: 60, skippedFrames: 0);
    expect(metrics.memoryBytes, isNull);
    expect(metrics.bufferSeconds, isNull);
    expect(metrics.fps, 60);
    expect(metrics.skippedFrames, 0);
  });

  test('perfMetricsProvider is autoDispose StreamProvider<PerfMetrics>', () {
    expect(perfMetricsProvider, isA<AutoDisposeStreamProvider<PerfMetrics>>());
  });
}
