import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/megav_text_styles.dart';

/// Mini brand mark — gradient square + horizontal cutout bar + optional
/// MegaV wordmark. Used in app/screen headers.
///
/// Cutout geometry pinned (per tasks.md sub-task 2.4):
/// - bar width: size * 0.60
/// - bar height: size * 0.12
/// - bar position: top: size * 0.55, centered horizontally
/// - bar color: AppColors.background (creates negative-space effect)
///
/// Maps to Requirements 2.1, 2.2, 2.3, 2.4.
class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 32, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wordmarkStyle = theme.extension<MegaVTextStyles>()?.displayLarge ?? theme.textTheme.titleLarge;

    final mark = SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Gradient square fill
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.activePalette.accent, AppColors.activePalette.accentGlow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(size * 0.18),
            ),
          ),
          // Cutout bar (horizontal slot)
          Positioned(
            left: size * 0.20,
            right: size * 0.20,
            top: size * 0.55,
            height: size * 0.12,
            child: Container(color: AppColors.background),
          ),
        ],
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.30),
        Text('MegaV', style: wordmarkStyle?.copyWith(fontSize: size * 0.55)),
      ],
    );
  }
}
