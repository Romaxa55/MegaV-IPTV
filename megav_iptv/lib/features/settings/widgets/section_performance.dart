import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/providers/providers.dart';
import '../../../core/ui/atoms/atoms.dart';
import 'mv_toggle.dart';
import 'perf_hero.dart';

/// UI-only Impeller engine toggle. Defaults to `true`. Not wired to any
/// real engine flag — the actual Impeller switch lives in a separate spec.
final impellerEnabledProvider = StateProvider<bool>((ref) => true);

/// UI-only parallax effect toggle. Defaults to `false`.
final parallaxEnabledProvider = StateProvider<bool>((ref) => false);

/// Composer for the «Производительность» Settings section: live perf
/// metrics tile grid + 3 visibility toggles.
///
/// The ABR toggle is re-exported here from [decoderConfigProvider] so
/// users can flip it from either Player or Performance section
/// (single source of truth — Req 7.9).
class SectionPerformance extends ConsumerWidget {
  const SectionPerformance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(decoderConfigProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Метрики'),
          SizedBox(height: 16.h),
          const PerfHero(),
          SizedBox(height: 48.h),
          const SectionTitle(title: 'Тумблеры'),
          SizedBox(height: 16.h),
          MvToggle(
            label: 'Impeller engine',
            value: ref.watch(impellerEnabledProvider),
            onChanged: (v) => ref.read(impellerEnabledProvider.notifier).state = v,
          ),
          SizedBox(height: 16.h),
          MvToggle(
            label: 'Эффекты parallax',
            value: ref.watch(parallaxEnabledProvider),
            onChanged: (v) => ref.read(parallaxEnabledProvider.notifier).state = v,
          ),
          SizedBox(height: 16.h),
          MvToggle(
            label: 'Adaptive Bitrate',
            value: config.abrEnabled ?? true,
            onChanged: (v) => ref.read(decoderConfigProvider.notifier).state = config.copyWith(abrEnabled: v),
          ),
        ],
      ),
    );
  }
}
