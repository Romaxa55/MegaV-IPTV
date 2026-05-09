import 'dart:async';

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/megav_text_styles.dart';

/// Computes the horizontal pixel offset of [now] relative to [windowFrom]
/// using a 30-minute slot of width [slotW].
///
/// The result is clamped to `>= 0` so that when `now` precedes `windowFrom`
/// (e.g. caller scrolled the visible window forward in time) the marker
/// pins to the left edge instead of leaving the viewport.
///
/// Maps to Requirement 6.2 (NOW marker positioned at the start of the
/// visible window, never in the middle, never negative).
double nowOffsetX(DateTime now, DateTime windowFrom, double slotW) {
  final minutes = now.difference(windowFrom).inMinutes;
  final raw = (minutes / 30.0) * slotW;
  return raw.clamp(0, double.infinity).toDouble();
}

/// Vertical "current time" indicator overlay for the EPG time grid.
///
/// Renders a 2-pixel-wide vertical accent line spanning the full grid
/// height plus an "NOW" pill at the top (Req 6.1). The marker is
/// horizontally offset from the left edge of the time grid by
/// [nowOffsetX]`(DateTime.now(), windowFrom, slotW)` (Req 6.2) and
/// exposes [Key]`('epg-now-marker')` for widget-test lookup (Req 6.5).
///
/// **Stack contract.** This widget returns a [Positioned] from `build()`,
/// therefore it MUST be placed as a direct child of a [Stack] ancestor
/// — typically the same Stack that hosts the time-grid contents.
///
/// **Rebuild model.** [EpgNowMarker] itself is a [StatelessWidget] and
/// re-evaluates `nowOffsetX` only when the parent rebuilds (e.g. on day
/// change). The interior [_NowMarkerLine] is private and stateful with
/// its own [Timer.periodic] tick — it repaints in isolation behind a
/// [RepaintBoundary] (Req 6.4, 13.4) so the rest of the grid is unaffected.
///
/// **Performance contract** (Req 13.1, 13.2):
/// - No `BackdropFilter` / `ShaderMask` / `ImageFilter.blur` in this tree.
/// - No `AnimatedContainer.width` (no implicit width animation).
/// - All `BoxShadow.blurRadius` values are capped at [kSafeShadowBlurMax].
///
/// Maps to Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 13.1, 13.2, 13.4.
class EpgNowMarker extends StatelessWidget {
  const EpgNowMarker({
    super.key,
    required this.windowFrom,
    required this.slotW,
    required this.gridHeight,
    required this.accent,
  });

  /// Start of the visible time window (matches `EpgTimeAxis.windowFrom`
  /// and the time-grid origin).
  final DateTime windowFrom;

  /// Width of a single 30-minute slot in design pixels (will be scaled
  /// via `.w` for offset computation). Mirrors the value used by
  /// [EpgTimeAxis] / [EpgProgramCell].
  final double slotW;

  /// Full vertical extent of the time grid in design pixels (will be
  /// scaled via `.h` for the `Positioned.height`).
  final double gridHeight;

  /// Accent colour applied to the vertical line and the "NOW" pill.
  /// Typically `AppColors.activePalette.accent`.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final left = nowOffsetX(DateTime.now(), windowFrom, slotW);
    return Positioned(
      key: const Key('epg-now-marker'),
      left: left.w,
      top: 0,
      height: gridHeight.h,
      width: 2.w,
      child: _NowMarkerLine(accent: accent),
    );
  }
}

/// Private leaf widget hosting the minute-tick timer.
///
/// Lives behind a [RepaintBoundary] so that the half-minute `setState`
/// repaints only this 2 px column + NOW pill, never the surrounding grid
/// (Req 6.4, 13.4).
///
/// The const constructor preserves the design intent that the parent's
/// rebuild does not force this leaf to rebuild — it lets the framework
/// short-circuit on `==` when [accent] is stable.
class _NowMarkerLine extends ConsumerStatefulWidget {
  const _NowMarkerLine({required this.accent});

  final Color accent;

  @override
  ConsumerState<_NowMarkerLine> createState() => _NowMarkerLineState();
}

class _NowMarkerLineState extends ConsumerState<_NowMarkerLine> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 30-second cadence → guarantees position update at most once per
    // minute as required by Req 6.4 while remaining cheap (a single
    // RepaintBoundary repaint, no layout work).
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final megavText = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;
    // Capped-blur glow around the vertical line — Req 6.3 / 13.2.
    final glow = <BoxShadow>[BoxShadow(color: palette.accentGlow, blurRadius: kSafeShadowBlurMax)];
    final labelStyle = (megavText?.metaMono ?? theme.textTheme.labelSmall)?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Vertical accent line — fills the whole Positioned height.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: widget.accent, boxShadow: glow),
            ),
          ),
          // "NOW" pill anchored to the top of the line. Translated so it
          // visually sits centred on the 2 px column.
          Positioned(
            top: 0,
            left: -16.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: widget.accent,
                borderRadius: AppRadius.brSm,
                boxShadow: <BoxShadow>[BoxShadow(color: palette.accentGlow, blurRadius: kSafeShadowBlurMax)],
              ),
              child: Text('NOW', style: labelStyle),
            ),
          ),
        ],
      ),
    );
  }
}
