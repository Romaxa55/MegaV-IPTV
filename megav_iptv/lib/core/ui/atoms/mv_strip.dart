import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Decorative filmstrip — row of frame-shaped tiles with sprocket-hole
/// notches at top and bottom. Purely visual; no interaction, no focus,
/// no animation.
///
/// Notch geometry pinned per tasks.md sub-task 2.13:
/// - 4 notches per tile (2 top + 2 bottom)
/// - Each notch: width = tileWidth * 0.10, height = 4
/// - Top notches: top = -2, left = tileWidth * 0.20 and tileWidth * 0.70
/// - Bottom notches: bottom = -2, mirrored
///
/// Maps to Requirements 13.1, 13.2, 13.3.
class MvStrip extends StatelessWidget {
  const MvStrip({super.key, this.frameCount = 7, this.tileWidth = 80, this.tileHeight = 56});

  final int frameCount;
  final double tileWidth;
  final double tileHeight;

  Widget _tile() {
    final notchWidth = tileWidth * 0.10;
    const notchHeight = 4.0;
    return SizedBox(
      width: tileWidth,
      height: tileHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Frame border
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.cardBorder, width: 1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Top notches
          Positioned(
            top: -2,
            left: tileWidth * 0.20,
            child: Container(width: notchWidth, height: notchHeight, color: AppColors.background),
          ),
          Positioned(
            top: -2,
            left: tileWidth * 0.70,
            child: Container(width: notchWidth, height: notchHeight, color: AppColors.background),
          ),
          // Bottom notches
          Positioned(
            bottom: -2,
            left: tileWidth * 0.20,
            child: Container(width: notchWidth, height: notchHeight, color: AppColors.background),
          ),
          Positioned(
            bottom: -2,
            left: tileWidth * 0.70,
            child: Container(width: notchWidth, height: notchHeight, color: AppColors.background),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < frameCount; i++) ...[if (i > 0) const SizedBox(width: 4), _tile()],
      ],
    );
  }
}
