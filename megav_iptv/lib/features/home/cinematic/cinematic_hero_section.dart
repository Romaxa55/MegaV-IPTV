import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';

/// Cinematic hero section — full-bleed [SafeBackdrop] with combined gradient
/// + film grain overlay; foreground italic display title + LIVE [Chip] +
/// [MMLogo] + primary [MvButton] action.
///
/// First visible-UI widget of the cinematic home redesign. Maps to
/// Requirements 2.1-2.7, 8.1-8.4, 9.1-9.6, 13.1.
///
/// Layering (bottom → top):
/// 1. [SafeBackdrop] — pre-rendered blurred backdrop image (cached blur,
///    no per-frame runtime gaussian filter, Req 9.1).
/// 2. [DecoratedBox] with [combinedHeroGradient] — single combined vignette
///    + bottom-shade gradient (Req 9.3).
/// 3. [SafeFilmGrain] — baked-PNG grain overlay applied via `Opacity`,
///    not via blend-mode overlay; applied as a static layer per Req 9.4.
/// 4. Content column — italic display title with text-shadow capped at
///    [kSafeShadowBlurMax], LIVE chip + MMLogo + channel name meta row,
///    optional program label, primary `MvButton.primary` action.
///
/// Data is injected via constructor parameters (image / title / channelName /
/// programLabel / onWatch) so callers in Phase 5 can drive the hero from the
/// "current featured now-playing" provider while this widget stays presentational.
class CinematicHeroSection extends ConsumerWidget {
  const CinematicHeroSection({
    super.key,
    this.imageProvider,
    this.title,
    this.channelName,
    this.programLabel,
    this.onWatch,
  });

  /// Backdrop image to be pre-blurred by [SafeBackdrop]. When `null`, the
  /// backdrop falls back to the active palette background color.
  final ImageProvider? imageProvider;

  /// Italic display title rendered via `MegaVTextStyles.displayLarge` with
  /// `FontStyle.italic` (Req 2.5).
  final String? title;

  /// Channel name displayed next to the [MMLogo] in the meta row (Req 2.6).
  final String? channelName;

  /// Optional program label rendered with `MegaVTextStyles.metaMono`.
  final String? programLabel;

  /// Tap callback for the primary "Смотреть" CTA (Req 2.7).
  final VoidCallback? onWatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = AppColors.activePalette;
    final styles = theme.extension<MegaVTextStyles>();
    final titleStyle = (styles?.displayLarge ?? theme.textTheme.headlineLarge)?.copyWith(
      fontStyle: FontStyle.italic,
      color: palette.text,
      shadows: [
        Shadow(blurRadius: kSafeShadowBlurMax, color: Colors.black.withValues(alpha: 0.55), offset: const Offset(0, 2)),
      ],
    );
    final metaStyle = styles?.metaMono ?? theme.textTheme.labelSmall;

    // Hero height: 360 logical px on TV (1080p target), scaled down to at
    // most 38% of the window height on smaller viewports so the rails below
    // ("Сейчас в эфире", "Фильмы") remain visible without scrolling far.
    // Minimum 200 px keeps the CTA reachable.
    final windowH = MediaQuery.sizeOf(context).height;
    final heroHeight = windowH >= 900 ? 360.0 : (windowH * 0.38).clamp(200.0, 360.0);

    return SizedBox(
      key: const Key('cinematic-hero'),
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: pre-rendered blurred backdrop (Req 2.1, 9.1).
          SafeBackdrop(imageProvider: imageProvider, fallbackBackground: palette.background),
          // Layer 1: single combined gradient (vignette + bottom shade in
          // one render pass, Req 2.2 + 9.3).
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: combinedHeroGradient(palette))),
          ),
          // Layer 2: film-grain overlay (Req 2.3). Applied as a static
          // layer per Req 9.4 — never on scrolling content. SafeFilmGrain
          // requires a `child`; we feed it a transparent expander so the
          // grain composites over the gradient layer below.
          const Positioned.fill(
            child: IgnorePointer(child: SafeFilmGrain(opacity: 0.06, child: SizedBox.expand())),
          ),
          // Layer 3: content column.
          Positioned(
            left: 32,
            right: 32,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Meta row: LIVE chip + MMLogo + channel name (Req 2.6).
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Chip(label: 'LIVE', variant: ChipVariant.live),
                    const SizedBox(width: 12),
                    const MMLogo(size: 32),
                    const SizedBox(width: 12),
                    if (channelName != null && channelName!.isNotEmpty) Text(channelName!, style: metaStyle),
                  ],
                ),
                const SizedBox(height: 12),
                // Italic display title (Req 2.5).
                if (title != null && title!.isNotEmpty)
                  Text(title!, style: titleStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                // Optional program label.
                if (programLabel != null && programLabel!.isNotEmpty) Text(programLabel!, style: metaStyle),
                const SizedBox(height: 16),
                // Primary action (Req 2.7). Caller wires the FocusNode in
                // Phase 5 (cinematic_home_screen.dart) so the hero CTA
                // receives initial focus on mount.
                MvButton.primary(label: 'Смотреть', onPressed: onWatch),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
