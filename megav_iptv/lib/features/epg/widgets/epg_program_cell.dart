import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/playlist/models/epg_program.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Single programme cell rendered inside the EPG time grid.
///
/// Spans `ceil(duration / 30 min) * slotW` horizontal pixels (Req 4.4) and
/// occupies `rowH` vertical pixels. Renders the programme start time in
/// monospaced typography (`MegaVTextStyles.metaMono`, Req 4.2), the title in
/// `theme.textTheme.titleMedium` with **no italic** (Req 4.1, design hard
/// rule), an optional `MvTrack` progress indicator while `program.isNow`
/// (Req 4.3) and a `Chip(variant: ChipVariant.live)` LIVE badge (Req 4.3).
///
/// Focus emphasis uses an `AnimatedScale(1.0 → 1.05, 150 ms,
/// Curves.easeOutCubic)` (Req 4.5) wrapping an `AnimatedContainer` that
/// only animates `decoration` — never `width:` (Req 4.5, perf gate). The
/// focused-state glow is a single `BoxShadow` with `blurRadius:
/// kSafeShadowBlurMax` (Req 13.2) coloured by the active palette's
/// `accentGlow`. `SafeFocusRing.shadow` is not a public API in this code
/// base, so we hand-roll the equivalent capped-blur shadow inline.
///
/// The title `Shadow` for legibility over the cell background is also
/// capped at `kSafeShadowBlurMax` (Req 13.2).
///
/// Focus + tap wiring:
/// - `Focus(onFocusChange: ...)` reports gain-of-focus to the parent.
/// - The outermost `GestureDetector(onTap: onTap, behavior: opaque)`
///   handles select / tap. `onTap` is wired only when non-null so that
///   the widget remains hit-test transparent in test fixtures that pass
///   neither callback.
///
/// Performance contract (Req 13.1, 13.3):
/// - No GPU-blurring widgets in the build tree (perf-gate greps for
///   forbidden APIs must stay at zero hits).
/// - No animated `width:` on the implicit container — only `decoration`
///   is animated.
/// - All shadows respect `kSafeShadowBlurMax`.
///
/// Maps to Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 13.1, 13.2, 13.3.
class EpgProgramCell extends StatelessWidget {
  EpgProgramCell({
    required this.program,
    required this.focused,
    this.slotW = 180,
    this.rowH = 88,
    this.onTap,
    this.onFocusChange,
  }) : super(key: Key('epg-programme-cell-${program.id}'));

  /// Programme rendered by this cell. The cell never mutates the model.
  final EpgProgram program;

  /// Whether this cell is the currently-focused cell in the grid (Req 4.5).
  final bool focused;

  /// Logical width of a single 30-minute slot in design pixels (will be
  /// scaled via `.w`). Defaults to `180`, matching `EpgTimeAxis.slotW`.
  final double slotW;

  /// Logical height of a row in design pixels (will be scaled via `.h`).
  /// Defaults to `88`, matching `EpgChannelRail` row height.
  final double rowH;

  /// Tap / select handler — invoked on `GestureDetector.onTap`. May be
  /// `null` when the parent does not want activation.
  final VoidCallback? onTap;

  /// Invoked when this cell gains focus (Req 4.5). The callback fires
  /// only on focus-gained edges — not on focus-lost.
  final VoidCallback? onFocusChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final megavText = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    final metaStyle = megavText?.metaMono ?? theme.textTheme.labelSmall;
    final titleStyle = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      fontStyle: FontStyle.normal,
      shadows: const [Shadow(blurRadius: kSafeShadowBlurMax, color: Colors.black54)],
    );

    // Span = number of 30-minute slots covered, multiplied by slot width.
    // `program.duration` is `end - start`; we round up so a 31-minute show
    // still spans two slots visually (Req 4.4).
    final spanSlots = (program.duration.inMinutes / 30.0).ceil().clamp(1, 1 << 20);
    final spanW = spanSlots * slotW;

    // Resting / focused colours. Resting uses the second elevation
    // (palette.surface2 — also exposed via AppColors.surface), focused uses
    // the brand accent so the focused cell visibly pops.
    final restingColor = palette.surface2;
    final focusedColor = palette.accent;

    // Focus glow: hand-rolled because `SafeFocusRing.shadow` is not a
    // public static in this code base. blurRadius is capped at the safe
    // ceiling per Req 13.2.
    final focusedShadow = <BoxShadow>[BoxShadow(color: palette.accentGlow, blurRadius: kSafeShadowBlurMax)];

    Widget cell = SizedBox(
      width: spanW.w,
      height: rowH.h,
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus && onFocusChange != null) onFocusChange!();
        },
        child: AnimatedScale(
          scale: focused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            // Only `decoration` is animated — `width:` is forbidden by the
            // perf gate and would also cause expensive relayouts of
            // sibling cells.
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: focused ? focusedColor : restingColor,
              borderRadius: AppRadius.brMd,
              boxShadow: focused ? focusedShadow : null,
            ),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(_formatTime(program.start), style: metaStyle),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(program.title, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (program.isNow) ...[SizedBox(height: 4.h), MvTrack(progress: program.progress)],
                    ],
                  ),
                ),
                if (program.isNow) ...[SizedBox(width: 8.w), const Chip(variant: ChipVariant.live, label: 'LIVE')],
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      cell = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: cell);
    }
    return cell;
  }
}

/// Formats [t] as `HH:MM` in 24-hour format with zero-padding (Req 4.2).
///
/// Mirrors the formatter in `epg_time_axis.dart` so axis labels and cell
/// timestamps always render identically.
String _formatTime(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
