import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// Maximum BoxShadow / Shadow blurRadius safe on TV-Mali (rtd2851a).
/// Anything beyond this triggers per-frame gaussian re-rasterize.
/// Cross-cutting constant — also referenced by task 3.1 (shadow audit)
/// and Req 7.3.
const double kSafeShadowBlurMax = 12.0;

/// Translucent pill / chip / status badge with opaque tint background.
///
/// Replaces CSS `backdrop-filter: blur(20px)` over video on TV target,
/// where runtime gaussian blur over a Texture layer is catastrophic.
///
/// Visual trade-off: opaque tint loses the "frosted glass" effect but
/// remains palette-aware via [tint] (defaults to active palette surface).
///
/// Usage:
/// ```dart
/// SafePill(
///   child: Text('LIVE', style: theme.megavText.metaMono),
///   tint: AppColors.liveBadge,
///   alpha: 0.85,
/// )
/// ```
class SafePill extends StatelessWidget {
  const SafePill({
    super.key,
    required this.child,
    this.tint,
    this.alpha = 0.85,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final Widget child;
  final Color? tint;
  final double alpha;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? AppColors.surface;
    final filled = Color.fromRGBO(
      (base.r * 255.0).round() & 0xFF,
      (base.g * 255.0).round() & 0xFF,
      (base.b * 255.0).round() & 0xFF,
      alpha,
    );
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: filled, borderRadius: borderRadius ?? AppRadius.brSm),
      child: child,
    );
  }
}

/// Solid-color focus ring drawn outside child bounds via stacked
/// BoxShadow with `blurRadius: 0`.
///
/// Replaces CSS `outline: 3px solid var(--accent); outline-offset: 3px;`
/// — Flutter `Border` paints inside the box, not outside, so we use
/// two solid BoxShadow layers: inner one matches background (creates
/// the 3px gap), outer one is the ring color.
///
/// Transition between focused/unfocused completes within 150 ms
/// (Leanback `lb_card_activated_animation_duration`) via AnimatedContainer.
/// GPU-only animation — no relayout of siblings.
///
/// Usage:
/// ```dart
/// SafeFocusRing(
///   isFocused: focusNode.hasFocus,
///   child: PosterCard(...),
/// )
/// ```
class SafeFocusRing extends StatelessWidget {
  const SafeFocusRing({
    super.key,
    required this.child,
    this.isFocused = false,
    this.ringColor,
    this.gap = 3.0,
    this.thickness = 3.0,
    this.duration = const Duration(milliseconds: 150),
  });

  final Widget child;
  final bool isFocused;
  final Color? ringColor;
  final double gap;
  final double thickness;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final color = ringColor ?? AppColors.primary;
    return AnimatedContainer(
      duration: duration,
      curve: Curves.fastOutSlowIn,
      decoration: BoxDecoration(
        boxShadow: isFocused
            ? <BoxShadow>[
                // Outer: ring color (visible).
                BoxShadow(color: color, spreadRadius: gap + thickness, blurRadius: 0),
                // Inner: background color (creates the gap, simulates outline-offset).
                BoxShadow(color: AppColors.background, spreadRadius: gap, blurRadius: 0),
              ]
            : const <BoxShadow>[],
      ),
      child: child,
    );
  }
}
