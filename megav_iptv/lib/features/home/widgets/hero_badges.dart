import 'package:flutter/material.dart' hide Chip;

import '../../../core/ui/atoms/atoms.dart';

/// Backward-compat shim — internally delegates to [Chip] atom from
/// design-system-atoms. Public API preserved verbatim.
///
/// Mapping:
/// - showPulse: true  → Chip(variant: ChipVariant.live)
/// - showPulse: false → Chip(variant: ChipVariant.brand)
///
/// Legacy color/textColor/borderColor params become decorative no-ops —
/// Chip derives all colors from active palette per variant. Allowed
/// visual drift under Req 2.2 «negligible color drift» carry-over from
/// foundation #4.
class HeroBadge extends StatelessWidget {
  const HeroBadge({
    super.key,
    required this.text,
    required this.color,
    this.textColor,
    this.borderColor,
    this.showPulse = false,
    this.icon,
  });

  final String text;
  final Color color;
  final Color? textColor;
  final Color? borderColor;
  final bool showPulse;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: text,
      variant: showPulse ? ChipVariant.live : ChipVariant.brand,
      icon: icon != null ? Icon(icon, size: 14) : null,
    );
  }
}
