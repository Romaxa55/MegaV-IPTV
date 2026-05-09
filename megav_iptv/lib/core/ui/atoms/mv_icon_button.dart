import 'package:flutter/material.dart';

import '../../perf/perf_safe_widgets.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// 38×38 rounded icon button. Wraps content in [SafeFocusRing] when
/// focused (Req 16.3).
///
/// Maps to Requirements 11.1, 11.2, 11.3, 11.4, 16.3.
class MvIconButton extends StatelessWidget {
  const MvIconButton({super.key, required this.icon, required this.onPressed, this.size = 38, this.isFocused = false});

  final Widget icon;
  final VoidCallback onPressed;
  final double size;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: AppColors.surface,
      borderRadius: AppRadius.brSm,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.brSm,
        child: SizedBox.square(
          dimension: size,
          child: Center(child: icon),
        ),
      ),
    );

    return SafeFocusRing(isFocused: isFocused, child: btn);
  }
}
