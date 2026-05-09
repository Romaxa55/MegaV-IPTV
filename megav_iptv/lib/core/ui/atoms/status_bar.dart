import 'package:flutter/material.dart';

import '../../perf/perf_safe_widgets.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/megav_text_styles.dart';

/// Compact status pill displaying optional flag / city / temperature / time.
///
/// Used by the editorial home screen header to surface contextual info
/// (locale flag, city name, temperature in °C, formatted clock time). All
/// fields are optional — only non-null/non-empty values are rendered, with
/// 8 logical-pixel spacing between adjacent items.
///
/// Background uses [SafePill] (opaque tint, no runtime blur) per the
/// perf-safe primitives contract — Req 16.4. Tint defaults to
/// `AppColors.surface` (palette-backed `surface2` proxy) and rounding is
/// pinned to `AppRadius.brSm`.
///
/// No clock-tick logic lives here — `time` is provided by the caller.
///
/// When every field is null or empty the widget collapses to a
/// `SizedBox.shrink()` so it does not contribute padding to layouts.
///
/// Maps to Requirements 3.1, 3.2, 3.3, 3.4, 16.4 of `design-system-atoms`.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, this.flag, this.city, this.tempC, this.time});

  /// Optional flag emoji or short locale glyph (e.g. `🇷🇺`).
  final String? flag;

  /// Optional city label (e.g. `Москва`).
  final String? city;

  /// Optional temperature in degrees Celsius. Rendered as `<n>°C`.
  final int? tempC;

  /// Optional pre-formatted clock string (e.g. `21:42`). Caller owns ticking.
  final String? time;

  bool get _allEmpty =>
      (flag == null || flag!.isEmpty) &&
      (city == null || city!.isEmpty) &&
      tempC == null &&
      (time == null || time!.isEmpty);

  @override
  Widget build(BuildContext context) {
    if (_allEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final TextStyle? metaMono = theme.extension<MegaVTextStyles>()?.metaMono;
    final TextStyle? textStyle = metaMono ?? theme.textTheme.labelSmall;

    final children = <Widget>[];
    void addItem(Widget w) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      children.add(w);
    }

    if (flag != null && flag!.isNotEmpty) {
      addItem(Text(flag!, style: textStyle));
    }
    if (city != null && city!.isNotEmpty) {
      addItem(Text(city!, style: textStyle));
    }
    if (tempC != null) {
      addItem(Text('${tempC!}°C', style: textStyle));
    }
    if (time != null && time!.isNotEmpty) {
      addItem(Text(time!, style: textStyle));
    }

    return SafePill(
      tint: AppColors.surface,
      alpha: 0.85,
      borderRadius: AppRadius.brSm,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
