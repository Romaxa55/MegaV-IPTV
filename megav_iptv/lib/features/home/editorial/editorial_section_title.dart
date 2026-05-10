import 'package:flutter/material.dart' hide Chip;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';

/// Editorial section title — pixel-faithful to the JSX `.mv-section-title`.
///
/// JSX reference (`styles.css`):
/// ```css
/// .mv-section-title { display: flex; align-items: baseline; gap: 14px;
///   padding: 0 56px; margin-bottom: 18px; }
/// .mv-section-title h3 { font-family: var(--font-display); font-size: 32px;
///   font-weight: 500; text-shadow: 0 2px 18px rgba(0,0,0,0.55); }
/// .mv-section-title h3 em { font-style: italic; font-weight: 400;
///   color: color-mix(in oklab, var(--accent) 70%, var(--text) 30%); }
/// .mv-section-title .count { font-family: var(--font-mono); font-size: 11px;
///   color: var(--text-mute); letter-spacing: 0.1em; }
/// .mv-section-title .more { margin-left: auto; font-size: 12px;
///   color: var(--text-dim); letter-spacing: 0.08em;
///   text-transform: uppercase; font-family: var(--font-mono); }
/// ```
///
/// Visual contract:
/// 1. Label upright 32sp/w500 with soft drop-shadow.
/// 2. If [emphasis] non-null — italic w400 in accent-blend (70% accent + 30% text).
/// 3. If [count] non-null — mono 11sp badge.
/// 4. Trailing «ВСЕ →» label in mono uppercase pushed right via Spacer.
///
/// No horizontal padding is added here — the containing screen sets padding
/// on its ListView (padding: EdgeInsets.symmetric(horizontal: 56)) so the
/// title aligns with the JSX `padding: 0 56px`.
///
/// Perf contract: NO blur, NO ShaderMask, NO BoxShadow.blurRadius > 12.
class EditorialSectionTitle extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  EditorialSectionTitle({
    Key? key,
    required this.label,
    required this.emphasis,
    this.count,
    this.onMoreTap,
    this.moreLabel = 'ВСЕ →',
  }) : super(key: key ?? Key('editorial-section-title-$label'));

  /// Upright section heading (e.g. `Кино`).
  final String label;

  /// Italic emphasis fragment (e.g. `без расписания`).
  final String emphasis;

  /// Optional count badge.
  final int? count;

  /// Optional «more →» tap callback.
  final VoidCallback? onMoreTap;

  /// Label for the trailing more action.
  final String moreLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    // Display title: 32sp, w500, with soft shadow per JSX.
    final titleStyle = (styles?.displayLarge ?? theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w500,
      color: palette.text,
      shadows: const [Shadow(blurRadius: 12, color: Color(0x8C000000), offset: Offset(0, 2))],
    );

    // Italic emphasis: w400, accent blend (70% accent + 30% text).
    final emphasisStyle = (styles?.displayItalic ?? theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      color: Color.lerp(palette.accent, palette.text, 0.30),
      shadows: const [Shadow(blurRadius: 12, color: Color(0x8C000000), offset: Offset(0, 2))],
    );

    // Mono count badge: 11sp, textMute, letter-spacing 0.1em.
    final countStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 11,
      color: palette.textMute,
      letterSpacing: 0.1 * 11,
    );

    // Mono more action: 12sp, textDim, uppercase, letter-spacing 0.08em.
    final moreStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 12,
      color: palette.textDim,
      letterSpacing: 0.08 * 12,
    );

    final padded = count != null ? (count!).toString().padLeft(2, '0') : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: label, style: titleStyle),
              TextSpan(text: ' ', style: titleStyle),
              TextSpan(text: emphasis, style: emphasisStyle),
            ],
          ),
        ),
        if (padded != null) ...[const SizedBox(width: 14), Text(padded, style: countStyle)],
        const Spacer(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onMoreTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(moreLabel, style: moreStyle),
            ),
          ),
        ),
      ],
    );
  }
}
