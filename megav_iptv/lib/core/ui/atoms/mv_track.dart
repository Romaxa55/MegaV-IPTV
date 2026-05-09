import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Horizontal progress bar with optional glow knob. Animates `widthFactor`
/// only — no relayout of siblings (Req 12.4, 16.6).
///
/// Maps to Requirements 12.1, 12.2, 12.3, 12.4, 16.6.
class MvTrack extends StatelessWidget {
  const MvTrack({super.key, required this.progress, this.showKnob = false, this.height = 4});

  final double progress;
  final bool showKnob;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Background track
          Positioned.fill(child: ColoredBox(color: AppColors.surface)),
          // Animated fill — paint-only animation, no relayout
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            alignment: Alignment.centerLeft,
            widthFactor: clamped,
            heightFactor: 1.0,
            child: ColoredBox(color: AppColors.primary),
          ),
          // Optional knob at progress endpoint
          if (showKnob)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: FractionallySizedBox(
                widthFactor: clamped,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: height * 2,
                    height: height * 2,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
