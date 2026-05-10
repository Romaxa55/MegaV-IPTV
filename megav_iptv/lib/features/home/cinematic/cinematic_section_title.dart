import 'package:flutter/material.dart' hide Chip;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';

/// Cinematic section title — pixel-faithful to the JSX prototype.
///
/// JSX reference (`.kiro/design/megav-iptv-handoff/project/styles.css`):
///
/// ```css
/// .mv-section-title {
///   display: flex; align-items: baseline; gap: 14px;
///   padding: 0 56px; margin-bottom: 18px;
/// }
/// .mv-section-title h3 {
///   font-family: var(--font-display); font-size: 32px; font-weight: 500;
///   text-shadow: 0 2px 18px rgba(0,0,0,0.55);
/// }
/// .mv-section-title h3 em {
///   font-style: italic; font-weight: 400;
///   color: color-mix(in oklab, var(--accent) 70%, var(--text) 30%);
/// }
/// .mv-section-title .count {
///   font-family: var(--font-mono); font-size: 11px;
///   color: var(--text-mute); letter-spacing: 0.1em;
/// }
/// .mv-section-title .more {
///   margin-left: auto; font-size: 12px;
///   color: var(--text-dim); letter-spacing: 0.08em;
///   text-transform: uppercase; font-family: var(--font-mono);
/// }
/// ```
///
/// Visual contract:
/// 1. Display `title` upright at 32sp/w500 with the soft drop-shadow.
/// 2. If [emphasis] is non-null — append italic w400 word using the
///    accent-blend colour (70% accent, 30% text).
/// 3. If [count] is non-null — small mono badge two-digit zero-padded.
/// 4. Trailing «ВСЕ →» action label in mono uppercase, pushed right
///    via [Spacer]. The label is rendered for visual fidelity even
///    when [onMoreTap] is null (matches JSX behaviour where `more`
///    is always present).
class CinematicSectionTitle extends StatelessWidget {
  const CinematicSectionTitle({
    super.key,
    required this.label,
    this.emphasis,
    this.count,
    this.onMoreTap,
    this.moreLabel = 'ВСЕ →',
  });

  final String label;
  final String? emphasis;
  final int? count;
  final VoidCallback? onMoreTap;
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

    // Italic emphasis: w400, accent blend.
    final emphasisStyle =
        (styles?.displayItalic ??
                theme.textTheme.headlineMedium?.copyWith(fontStyle: FontStyle.italic) ??
                const TextStyle())
            .copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: Color.lerp(palette.accent, palette.text, 0.30),
              shadows: const [Shadow(blurRadius: 12, color: Color(0x8C000000), offset: Offset(0, 2))],
            );

    // Mono count badge: 11sp, text-mute, letter-spacing 0.1em.
    final countStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 11,
      color: palette.textMute,
      letterSpacing: 0.1 * 11,
    );

    // Mono more action: 12sp, text-dim, uppercase, letter-spacing 0.08em.
    final moreStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 12,
      color: palette.textDim,
      letterSpacing: 0.08 * 12,
    );

    final padded = (count?.toString() ?? '').padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 56, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Title + optional italic emphasis as a single rich-text run so the
          // baseline and inter-word spacing match the JSX `<h3>{title} <em>...</em></h3>`.
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: label, style: titleStyle),
                if (emphasis != null) ...[
                  TextSpan(text: ' ', style: titleStyle),
                  TextSpan(text: emphasis!, style: emphasisStyle),
                ],
              ],
            ),
          ),
          if (count != null) ...[const SizedBox(width: 14), Text(padded, style: countStyle)],
          const Spacer(),
          // Trailing more action — visually present even without callback.
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
      ),
    );
  }
}
