import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Pulsing red "LIVE" indicator dot for mobile screens.
///
/// Animates opacity over a 1.5 s reversing cycle to draw the eye to live
/// programming (Req 7.7). Wrapped in a [RepaintBoundary] so the animation
/// does not invalidate ancestor layers (Req 4.5 / 11.3).
class MLiveDot extends StatefulWidget {
  const MLiveDot({super.key});

  @override
  State<MLiveDot> createState() => _MLiveDotState();
}

class _MLiveDotState extends State<MLiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const Key('m-live-dot'),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.activePalette.live.withValues(alpha: _ctrl.value),
          ),
        ),
      ),
    );
  }
}
