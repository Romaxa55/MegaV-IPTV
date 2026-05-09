import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/player/decoder_config.dart';
import '../../../core/providers/providers.dart';
import '../../../core/ui/atoms/atoms.dart';
import 'mv_picker.dart';
import 'mv_toggle.dart';

/// Composer for the «Плеер» Settings section: decoder mode picker,
/// buffer size picker, ABR toggle, audio-passthrough toggle.
///
/// Reads/writes [decoderConfigProvider] only — no other player layer
/// imports (Req 5.7).
class SectionPlayer extends ConsumerWidget {
  const SectionPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(decoderConfigProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Режим декодера'),
          SizedBox(height: 16.h),
          MvPicker<DecoderMode>(
            options: DecoderMode.values,
            value: config.decoderMode,
            labelOf: (m) => m.label,
            onChanged: (m) => ref.read(decoderConfigProvider.notifier).state = config.copyWith(decoderMode: m),
          ),
          SizedBox(height: 32.h),
          const SectionTitle(title: 'Размер буфера'),
          SizedBox(height: 16.h),
          MvPicker<BufferMode>(
            options: BufferMode.values,
            value: config.bufferMode,
            labelOf: (m) => m.label,
            onChanged: (m) => ref.read(decoderConfigProvider.notifier).state = config.copyWith(bufferMode: m),
          ),
          SizedBox(height: 32.h),
          MvToggle(
            label: 'Adaptive Bitrate',
            value: config.abrEnabled ?? true,
            onChanged: (v) => ref.read(decoderConfigProvider.notifier).state = config.copyWith(abrEnabled: v),
          ),
          SizedBox(height: 16.h),
          MvToggle(
            label: 'Audio Passthrough',
            value: config.audioPassthrough ?? false,
            onChanged: (v) => ref.read(decoderConfigProvider.notifier).state = config.copyWith(audioPassthrough: v),
          ),
        ],
      ),
    );
  }
}
