import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_metrics_provider.dart';
import 'stat_tile.dart';

/// 4-tile grid wrapping FPS / Skipped / Memory / Buffer [StatTile]s.
///
/// Each tile is its own [ConsumerWidget] reading a single field of
/// [perfMetricsProvider] via [Ref.select] and wrapped in
/// [RepaintBoundary] so a metric change rebuilds only that tile
/// (Req 7.7, 12.5).
class PerfHero extends StatelessWidget {
  const PerfHero({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16.h,
      crossAxisSpacing: 16.w,
      childAspectRatio: 2,
      children: const [_StatTileFps(), _StatTileSkipped(), _StatTileMemory(), _StatTileBuffer()],
    );
  }
}

class _StatTileFps extends ConsumerWidget {
  const _StatTileFps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fps = ref.watch(perfMetricsProvider.select((async) => async.valueOrNull?.fps));
    return RepaintBoundary(
      child: StatTile(label: 'FPS', value: fps != null ? fps.toStringAsFixed(0) : '—', sub: 'avg за 60 кадров'),
    );
  }
}

class _StatTileSkipped extends ConsumerWidget {
  const _StatTileSkipped();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skipped = ref.watch(perfMetricsProvider.select((async) => async.valueOrNull?.skippedFrames));
    return RepaintBoundary(
      child: StatTile(label: 'Пропущено', value: skipped?.toString() ?? '—', sub: 'кадров > 16.7 ms'),
    );
  }
}

class _StatTileMemory extends ConsumerWidget {
  const _StatTileMemory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memBytes = ref.watch(perfMetricsProvider.select((async) => async.valueOrNull?.memoryBytes));
    final memMb = memBytes != null ? (memBytes / 1024 / 1024).round() : null;
    return RepaintBoundary(
      child: StatTile(label: 'Память', value: memMb != null ? '$memMb MB' : '—', sub: 'maxRss'),
    );
  }
}

class _StatTileBuffer extends ConsumerWidget {
  const _StatTileBuffer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buf = ref.watch(perfMetricsProvider.select((async) => async.valueOrNull?.bufferSeconds));
    return RepaintBoundary(
      child: StatTile(label: 'Буфер', value: buf != null ? '${buf.toStringAsFixed(1)}s' : '—', sub: 'wait override'),
    );
  }
}
