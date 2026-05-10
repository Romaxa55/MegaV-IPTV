import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import 'font_pair_picker.dart';
import 'palette_swatches.dart';

/// Composer for the «Тема и палитра» + «Шрифтовая пара» Settings section.
///
/// JSX reference (`settings-v2.jsx`):
/// ```jsx
/// <SLabel>Воспроизведение</SLabel>
/// <div style={{fontFamily:"var(--font-display)", fontWeight:600,
///   fontSize:28, lineHeight:1.1, letterSpacing:"-0.02em",
///   margin:"10px 0 18px"}}>Плеер и переходы</div>
/// ```
/// Section sub-titles use display 28sp, w600, ls=-0.02em.
class SectionAppearance extends ConsumerWidget {
  const SectionAppearance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    // Eyebrow label: mono 10sp, ls=0.22em, uppercase, textMute.
    final eyebrowStyle = (styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontSize: 10,
      letterSpacing: 0.22 * 10,
      color: palette.textMute,
    );

    // Section sub-title: display 28sp, w600, ls=-0.02em.
    final subTitleStyle = (styles?.displayLarge ?? theme.textTheme.headlineSmall ?? const TextStyle()).copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.1,
      letterSpacing: -0.02 * 28,
      color: palette.text,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(56, 32, 56, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section eyebrow.
          Text('ВНЕШНИЙ ВИД', style: eyebrowStyle),
          const SizedBox(height: 10),
          // Section title — JSX: "Тема и палитра".
          Text('Тема и палитра', style: subTitleStyle),
          const SizedBox(height: 18),
          const PaletteSwatches(),
          const SizedBox(height: 36),
          // Section eyebrow.
          Text('ТИПОГРАФИКА', style: eyebrowStyle),
          const SizedBox(height: 10),
          // Section title — JSX: "Шрифтовая пара".
          Text('Шрифтовая пара', style: subTitleStyle),
          const SizedBox(height: 18),
          const FontPairPicker(),
        ],
      ),
    );
  }
}
