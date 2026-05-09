import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/megav_text_styles.dart';

/// Small "M" channel badge — fixed 38×38 logical pixels by default. Used as
/// channel branding accent next to a poster.
///
/// Maps to Requirements 6.1, 6.2, 6.3.
class MMLogo extends StatelessWidget {
  const MMLogo({super.key, this.size = 38, this.background});

  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayStyle = theme.extension<MegaVTextStyles>()?.displayLarge ?? theme.textTheme.titleMedium;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      child: Text(
        'M',
        style: (displayStyle ?? const TextStyle()).copyWith(
          color: Colors.white,
          fontSize: size * 0.50,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
