import 'package:flutter/material.dart' hide Chip;

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Horizontal day picker covering today − 2 … today + 4 (7 cells).
///
/// JSX reference (`epg-v2.jsx` DayPicker):
/// ```jsx
/// <button className={`mv-btn ${active ? "primary" : "ghost"}`}
///   style={{padding:"10px 14px", fontSize:12, minWidth:76,
///     flexDirection:"column", gap:2,
///     fontFamily:"var(--font-mono)", letterSpacing:"0.1em"}}>
///   <span style={{fontSize:10, opacity:0.7}}>СЕГОДНЯ / ВТ</span>
///   <span>12.05</span>
/// </button>
/// ```
///
/// Active day: SafePill with column child.
/// Inactive days: MvButton.ghost with column label child.
///
/// Maps to Requirements 7.1–7.5, 13.1, 13.2.
class EpgDayPicker extends StatelessWidget {
  const EpgDayPicker({super.key, required this.today, required this.selectedOffset, required this.onDaySelected});

  final DateTime today;
  final int selectedOffset;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('epg-day-picker'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var offset = -2; offset <= 4; offset++) ...[
          _buildDayCell(context, offset),
          if (offset < 4) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, int offset) {
    final date = today.add(Duration(days: offset));
    final dayLabel = _formatDayLabel(date, offset);
    final dateLabel = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    final isActive = offset == selectedOffset;
    final palette = AppColors.activePalette;

    // JSX: active → primary (bg=var(--text), color=var(--bg))
    //       ghost → transparent + border.
    final fgTop = isActive
        ? palette.background.withAlpha(0xB3) // 70% bg = approximation of 0.7 opacity
        : palette.textMute;
    final fgDate = isActive ? palette.background : palette.text;

    final cellContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // JSX: fontSize 10, opacity 0.7.
        Text(
          dayLabel,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            letterSpacing: 0.1 * 10,
            color: fgTop,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        // JSX: main date text, fontSize 12.
        Text(
          dateLabel,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            letterSpacing: 0.1 * 12,
            color: fgDate,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );

    if (isActive) {
      return GestureDetector(
        onTap: () => onDaySelected(offset),
        behavior: HitTestBehavior.opaque,
        child: SafePill(
          tint: palette.text,
          alpha: 1.0,
          borderRadius: BorderRadius.circular(10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 48), child: cellContent),
        ),
      );
    }

    // Inactive: MvButton.ghost. Label uses separator for readability;
    // the button sizes to its content naturally (no width constraint).
    return MvButton.ghost(
      label: '$dayLabel  $dateLabel',
      onPressed: () => onDaySelected(offset),
      size: MvButtonSize.small,
    );
  }

  static String _formatDayLabel(DateTime date, int offset) {
    if (offset == 0) return 'СЕГОДНЯ';
    if (offset == -1) return 'ВЧЕРА';
    if (offset == 1) return 'ЗАВТРА';
    const weekdayShort = <String>['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    return weekdayShort[date.weekday - 1];
  }
}
