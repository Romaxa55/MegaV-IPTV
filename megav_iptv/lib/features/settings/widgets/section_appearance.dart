import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/ui/atoms/atoms.dart';
import 'font_pair_picker.dart';
import 'palette_swatches.dart';

/// Composer for the «Тема и палитра» + «Шрифтовая пара» Settings section.
class SectionAppearance extends ConsumerWidget {
  const SectionAppearance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Тема и палитра'),
          SizedBox(height: 16.h),
          const PaletteSwatches(),
          SizedBox(height: 48.h),
          const SectionTitle(title: 'Шрифтовая пара'),
          SizedBox(height: 16.h),
          const FontPairPicker(),
        ],
      ),
    );
  }
}
