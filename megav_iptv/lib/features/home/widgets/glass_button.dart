import 'package:flutter/material.dart';

import '../../../core/ui/atoms/atoms.dart';

/// Compact 48×48 icon button. Backward-compat shim — internally delegates
/// to [MvIconButton] from design-system-atoms.
///
/// Public API preserved: `GlassButton({Key? key, required IconData icon,
/// required VoidCallback onTap})`.
class GlassButton extends StatelessWidget {
  const GlassButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MvIconButton(
      icon: Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.50)),
      onPressed: onTap,
      size: 48,
    );
  }
}
