import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/megav_text_styles.dart';

/// Sticky horizontal time axis for the EPG screen.
///
/// Renders [slotCount] half-hour slots starting at [windowFrom]. The header
/// shares its [horizontalCtl] with the programme grid (Req 5.1, 5.2) so
/// the axis and programme cells scroll in lock-step. The axis itself never
/// accepts user pan input — [NeverScrollableScrollPhysics] is intentional;
/// horizontal motion is driven exclusively by the time-grid controller
/// (Req 5.3).
///
/// Each slot is a fixed-width [SizedBox] of [slotW] (default 180.w) and
/// 32.h tall (Req 5.4). Labels are formatted as `HH:MM` (24h, zero-padded)
/// using `MegaVTextStyles.metaMono` (Req 5.5).
///
/// Performance contract (Req 13.1, 13.5):
/// - No GPU-blurring widgets (the perf-gate greps must remain at zero
///   hits) and no implicit-animation containers in the hot path.
/// - `cacheExtent: 1500`, `addAutomaticKeepAlives: true`,
///   `addRepaintBoundaries: true`, `clipBehavior: Clip.none`.
///
/// Maps to Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 13.1, 13.5.
class EpgTimeAxis extends StatelessWidget {
  const EpgTimeAxis({
    super.key,
    required this.windowFrom,
    required this.horizontalCtl,
    this.slotCount = 10,
    this.slotW = 180,
  });

  /// Start of the visible time window. Slot `i` covers
  /// `[windowFrom + i*30min, windowFrom + (i+1)*30min)`.
  final DateTime windowFrom;

  /// Number of half-hour slots to render. Defaults to 10 (5 hours).
  final int slotCount;

  /// Shared horizontal scroll controller — co-owned by [EpgTimeAxis] and
  /// the programme grid (Req 5.1, 5.2). The caller owns the controller's
  /// lifecycle; this widget never disposes it.
  final ScrollController horizontalCtl;

  /// Logical width of a single slot in design pixels (will be scaled via
  /// `.w`). Defaults to 180.
  final double slotW;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final megavText = theme.extension<MegaVTextStyles>();
    final metaStyle = megavText?.metaMono ?? theme.textTheme.labelSmall;

    return SizedBox(
      key: const Key('epg-time-axis'),
      height: 32.h,
      child: ListView.builder(
        controller: horizontalCtl,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        cacheExtent: 1500,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        clipBehavior: Clip.none,
        itemCount: slotCount,
        itemBuilder: (ctx, i) {
          final slotTime = windowFrom.add(Duration(minutes: 30 * i));
          return SizedBox(
            width: slotW.w,
            child: Center(child: Text(_formatTime(slotTime), style: metaStyle)),
          );
        },
      ),
    );
  }
}

/// Formats [t] as `HH:MM` in 24-hour format with zero-padding (Req 5.5).
String _formatTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
