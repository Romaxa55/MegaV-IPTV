import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';

/// Editorial masthead — print-magazine styled section header that combines
/// an upright label with an italic emphasis fragment, terminated by a mono
/// dateline and issue counter, all separated from the page body by a
/// hairline bottom border.
///
/// Typography is sourced from the registered [MegaVTextStyles] theme
/// extension (`displayLarge` for the title, `metaMono` for the dateline).
/// Colors are read through the active [AppPalette] via
/// `AppColors.activePalette` — the project does not register the palette
/// as a [ThemeExtension]; the documented bridge is the static accessor
/// (see `lib/core/theme/app_colors.dart`).
///
/// No backdrops, no shaders, no soft blurs — the surface is a flat
/// hairline-bordered container. Maps to Requirements 2.1, 2.2, 2.3, 2.4,
/// 2.5, 9.1, 9.2 and 13.1 of `home-editorial-redesign`.
class EditorialMasthead extends StatelessWidget {
  const EditorialMasthead({
    super.key,
    required this.label,
    required this.emphasis,
    required this.dateLine,
    required this.issueNumber,
  });

  /// Upright label text (e.g. `Главная`).
  final String label;

  /// Italic emphasis fragment appended after the label (e.g. `сегодня`).
  final String emphasis;

  /// Pre-formatted dateline (e.g. `9 МАЯ 2026`). Caller owns formatting.
  final String dateLine;

  /// Issue number rendered as a 3-digit zero-padded counter (e.g. `127`
  /// becomes `№127`, `7` becomes `№007`).
  final int issueNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    final displayLarge = styles?.displayLarge ?? theme.textTheme.displayLarge ?? const TextStyle();
    final metaMono = styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle();

    return Container(
      key: const Key('editorial-masthead'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: label, style: displayLarge),
                  TextSpan(
                    text: ' $emphasis',
                    style: displayLarge.copyWith(fontStyle: FontStyle.italic, color: palette.textDim),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '$dateLine · ВЫПУСК №${issueNumber.toString().padLeft(3, '0')}',
            style: metaMono.copyWith(color: palette.textMute),
          ),
        ],
      ),
    );
  }
}
