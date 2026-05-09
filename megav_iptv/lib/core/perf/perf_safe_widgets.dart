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
