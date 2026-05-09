import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';

/// Single metadata item in the hero meta row (year / channel name / quality / etc).
class HeroMetaItem {
  const HeroMetaItem({required this.label, this.isAccent = false, this.isGold = false});

  final String label;
  final bool isAccent;
  final bool isGold;
}

/// Hero meta block — title + meta row + synopsis + optional chips.
///
/// Maps to design.md §3, Req 3.1-3.6, 9.2.
class HeroMeta extends StatelessWidget {
  const HeroMeta({super.key, required this.title, this.metaItems = const [], this.synopsis, this.chips = const []});

  final String title;
  final List<HeroMetaItem> metaItems;
  final String? synopsis;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    final titleStyle = (styles?.displayLarge ?? theme.textTheme.headlineLarge)?.copyWith(
      fontStyle: FontStyle.italic,
      fontSize: 96.sp,
      color: palette.text,
      shadows: [
        Shadow(
          blurRadius: kSafeShadowBlurMax > 8 ? 8 : kSafeShadowBlurMax,
          color: Colors.black.withValues(alpha: 0.55),
          offset: const Offset(0, 2),
        ),
      ],
    );
    final metaStyle = styles?.metaMono ?? theme.textTheme.labelSmall;
    final synopsisStyle = styles?.bodyDefault ?? theme.textTheme.bodyMedium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chips.isNotEmpty) ...[Wrap(spacing: 8.w, children: chips), SizedBox(height: 12.h)],
        Text(title, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (metaItems.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Wrap(
            spacing: 14.w,
            runSpacing: 8.h,
            children: metaItems
                .where((m) => m.label.isNotEmpty)
                .map(
                  (m) => Text(
                    m.label,
                    style: metaStyle?.copyWith(color: m.isAccent ? palette.accent : (m.isGold ? palette.gold : null)),
                  ),
                )
                .toList(),
          ),
        ],
        if (synopsis != null && synopsis!.isNotEmpty) ...[
          SizedBox(height: 18.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720.w),
            child: Text(synopsis!, style: synopsisStyle, maxLines: 4, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );
  }
}
