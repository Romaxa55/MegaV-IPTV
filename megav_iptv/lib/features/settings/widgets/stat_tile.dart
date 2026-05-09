import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/megav_text_styles.dart';

/// Direction modifier rendered next to [StatTile.sub].
enum TrendDirection { up, down, flat }

/// Pure presentation tile for a single stat — label + large value + sub-line
/// (with optional trend arrow). No stream subscriptions; testable without
/// any provider scope (Req 7.1, 14.1).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.sub, this.trend});

  /// Top-line caption (e.g. «FPS»).
  final String label;

  /// Headline number / string (e.g. «60»).
  final String value;

  /// Sub-line caption (e.g. «avg за 60 кадров»).
  final String sub;

  /// Optional trend arrow rendered after [sub].
  final TrendDirection? trend;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final labelStyle = styles?.bodyDim ?? theme.textTheme.bodySmall;
    final valueStyle = (styles?.displayLarge ?? theme.textTheme.displayMedium)?.copyWith(
      fontSize: 44.sp,
      color: palette.text,
    );
    final subStyle = styles?.bodyDim ?? theme.textTheme.bodySmall;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: palette.surface1, borderRadius: AppRadius.brMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: labelStyle),
          SizedBox(height: 8.h),
          Text(value, style: valueStyle, maxLines: 1),
          SizedBox(height: 4.h),
          Row(
            children: [
              Flexible(
                child: Text(sub, style: subStyle, overflow: TextOverflow.ellipsis),
              ),
              if (trend != null) ...[SizedBox(width: 4.w), _TrendArrow(trend: trend!)],
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendArrow extends StatelessWidget {
  const _TrendArrow({required this.trend});

  final TrendDirection trend;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final (icon, color) = switch (trend) {
      TrendDirection.up => (Icons.arrow_upward, palette.good),
      TrendDirection.down => (Icons.arrow_downward, palette.live),
      TrendDirection.flat => (Icons.arrow_forward, palette.textDim),
    };
    return Icon(icon, size: 14.sp, color: color);
  }
}
