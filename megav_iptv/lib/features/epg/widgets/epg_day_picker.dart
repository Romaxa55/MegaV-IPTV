import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Horizontal day picker covering today − 2 … today + 4 (7 cells).
///
/// Active day uses [SafePill] accent fill wrapped in [SafeFocusRing];
/// inactive days render via [MvButton.ghost]. Atoms-only — no
/// `RawMaterialButton`. Maps to Requirements 7.1, 7.2, 7.3, 7.4, 7.5,
/// 13.1, 13.2.
class EpgDayPicker extends StatelessWidget {
  const EpgDayPicker({super.key, required this.today, required this.selectedOffset, required this.onDaySelected});

  /// "Today" anchor — the cell at offset 0 corresponds to this date.
  final DateTime today;

  /// Currently selected day offset relative to [today]. Expected range
  /// `-2..+4`; values outside the range render no active cell.
  final int selectedOffset;

  /// Invoked with the offset (relative to [today]) of the tapped cell.
  /// The caller is responsible for re-fetching programmes for the
  /// new day window (Req 7.3).
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('epg-day-picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var offset = -2; offset <= 4; offset++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: _buildDayCell(context, offset),
          ),
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, int offset) {
    final date = today.add(Duration(days: offset));
    final label = _formatDayLabel(date, offset);
    final isActive = offset == selectedOffset;

    if (isActive) {
      // Active: SafeFocusRing(isFocused: true) + SafePill accent fill
      // (Req 7.2). The pill wraps a tappable inner so re-tapping the
      // active day still surfaces a callback to the parent (idempotent).
      return SafeFocusRing(
        isFocused: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onDaySelected(offset),
          child: SafePill(
            tint: AppColors.accent,
            alpha: 1.0,
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
            child: Text(
              label,
              style: (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(color: Colors.white),
            ),
          ),
        ),
      );
    }

    // Inactive: ghost MvButton (transparent fill + lineStrong outline).
    // No focus ring — focus traversal is handled by the parent's
    // FocusTraversalGroup, which ensures the ring only renders when
    // the user lands on this cell via D-pad.
    return MvButton.ghost(label: label, onPressed: () => onDaySelected(offset));
  }

  /// Hand-rolled Russian short day label (no `intl` dependency at the
  /// atom layer): "Сегодня" / "Вчера" / "Завтра" for offsets 0/-1/+1,
  /// otherwise `«${weekdayShort} ${day} ${monthShort}»` (e.g. «Пн 12 май»).
  static String _formatDayLabel(DateTime date, int offset) {
    if (offset == 0) return 'Сегодня';
    if (offset == -1) return 'Вчера';
    if (offset == 1) return 'Завтра';

    const weekdayShort = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const monthShort = <String>['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    // `date.weekday` is 1..7 (Mon..Sun); `date.month` is 1..12.
    final wd = weekdayShort[date.weekday - 1];
    final mo = monthShort[date.month - 1];
    return '$wd ${date.day} $mo';
  }
}
