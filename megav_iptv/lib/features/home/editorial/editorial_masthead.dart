import 'package:flutter/material.dart' hide Chip;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';

/// Editorial masthead — print-magazine styled section header.
///
/// JSX reference (`home-editorial.jsx` masthead block):
/// ```jsx
/// <div style={{
///   fontFamily: "var(--font-display)", fontStyle: "italic",
///   fontSize: 56, lineHeight: 1, letterSpacing: "-0.01em"
/// }}>Главная <em style={{color:"var(--text-dim)"}}>сегодня</em></div>
/// <div style={{
///   fontFamily: "var(--font-mono)", fontSize: 11,
///   letterSpacing: "0.16em", color: "var(--text-mute)"
/// }}>9 МАЯ 2026 · ВЫПУСК №127</div>
/// ```
/// Container: `padding: "8px 56px 28px"`, `borderBottom: "1px solid var(--line)"`.
///
/// Typography spec:
/// - Label + emphasis: display italic 56sp, lineHeight 1.0, letterSpacing -0.01em.
/// - Emphasis color: `textDim`.
/// - Dateline: mono 11sp, letterSpacing 0.16em (= 0.16 * 11 = 1.76 lp), textMute.
///
/// Perf contract: NO blur, NO ShaderMask, NO BoxShadow.blurRadius > 12.
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

  /// Italic emphasis fragment (e.g. `сегодня`).
  final String emphasis;

  /// Pre-formatted dateline (e.g. `9 МАЯ 2026`).
  final String dateLine;

  /// Issue number (e.g. `127` → `ВЫПУСК №127`).
  final int issueNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    // Base display style — 56sp italic, lh=1.0, ls=-0.01em.
    final baseDisplay = styles?.displayItalic ?? theme.textTheme.headlineLarge ?? const TextStyle();
    final displayStyle = baseDisplay.copyWith(
      fontSize: 56,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      height: 1.0,
      letterSpacing: -0.01 * 56,
      color: palette.text,
    );
    final emphasisStyle = displayStyle.copyWith(color: palette.textDim);

    // Mono dateline — 11sp, ls=0.16em.
    final monoBase = styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle();
    final dateStyle = monoBase.copyWith(fontSize: 11, letterSpacing: 0.16 * 11, color: palette.textMute);

    return Container(
      key: const Key('editorial-masthead'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      // JSX: paddingBottom 16 inside the masthead container.
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: label, style: displayStyle),
                  TextSpan(text: ' $emphasis', style: emphasisStyle),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text('$dateLine · ВЫПУСК №${issueNumber.toString().padLeft(3, '0')}', style: dateStyle),
        ],
      ),
    );
  }
}
