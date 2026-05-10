import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Editorial film-reel strip — a horizontal `КАНАЛЫ ↓` eyebrow on the
/// left, a decorative [MvStrip] of frame-shaped tiles in the middle, and
/// a `NN / NNN` channel counter on the right.
///
/// The strip is purely decorative — no interaction, no focus, no
/// animation. It surfaces channel-count metadata in a print-magazine
/// idiom (mono eyebrow + filmstrip + counter) without introducing any
/// blur or shader effect.
///
/// **Perf contract**: NO [BackdropFilter], NO [ShaderMask], NO blur
/// (Req 9.1, 9.2, 13.3).
///
/// Maps to Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 9.1, 9.2 and 13.1 of
/// `home-editorial-redesign`.
class EditorialFilmReelStrip extends StatelessWidget {
  const EditorialFilmReelStrip({
    super.key,
    required this.channelCount,
    required this.activeIndex,
    this.frameCount = 18,
  });

  /// Total channel count rendered as the right-hand denominator (zero-
  /// padded to 3 digits, e.g. `124` → `124`, `7` → `007`).
  final int channelCount;

  /// Currently active channel index (zero-based) rendered as the left-
  /// hand numerator (zero-padded to 2 digits, e.g. `4` → `05`).
  final int activeIndex;

  /// Number of decorative frames in the [MvStrip] band.
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;
    final metaMono = styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle();

    final activeStr = (activeIndex + 1).toString().padLeft(2, '0');
    final totalStr = channelCount.toString().padLeft(3, '0');

    return Row(
      key: const Key('editorial-film-reel-strip'),
      children: [
        Text('КАНАЛЫ ↓', style: metaMono.copyWith(color: palette.textMute, letterSpacing: 0.16)),
        SizedBox(width: 18.w),
        Expanded(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: MvStrip(frameCount: frameCount),
            ),
          ),
        ),
        SizedBox(width: 18.w),
        Text('$activeStr / $totalStr', style: metaMono.copyWith(color: palette.textMute, letterSpacing: 0.12)),
      ],
    );
  }
}
