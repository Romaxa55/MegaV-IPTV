import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/megav_text_styles.dart';

/// Single keycap-styled pill used by `RemoteHint` to render arrow / OK / BACK
/// keycaps. Compact size (~26 logical pixels height) suitable for inline hint
/// rows.
///
/// Visuals are pinned to design tokens:
/// - background: `AppColors.surface` (palette-backed `surface2` proxy)
/// - rounding: `AppRadius.brXs`
/// - border: 1 logical pixel using `AppColors.cardBorder` (palette-backed
///   `lineStrong`)
/// - text: `MegaVTextStyles.metaMono` from the active theme extension, with a
///   safe fallback to `Theme.of(context).textTheme.labelSmall` when the
///   extension is absent (e.g. in lightweight test harnesses)
///
/// Maps to Requirements 14.1, 14.2, 14.3 of `design-system-atoms`.
class MvKey extends StatelessWidget {
  const MvKey({super.key, required this.glyph, this.height = 26});

  /// Visible character / label rendered inside the keycap (e.g. `↑`, `OK`,
  /// `BACK`).
  final String glyph;

  /// Logical pixel height of the pill. Defaults to 26 to match the inline
  /// hint-row sizing called out in design.md § Components > 13 MvKey.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final TextStyle? metaMono = theme.extension<MegaVTextStyles>()?.metaMono;
    final TextStyle? textStyle = metaMono ?? theme.textTheme.labelSmall;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brXs,
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Text(glyph, style: textStyle),
    );
  }
}
