import 'package:flutter/material.dart' hide Chip;

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/player/player_manager.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/atoms/atoms.dart';
import 'cinematic_hero_content.dart';

/// Full-bleed cinematic hero block — backdrop + gradient + film grain +
/// header row + [CinematicHeroContent].
///
/// Extracted from [CinematicHomeScreen] to stay within the 600-line per-file
/// pre-commit limit. This widget is stateless; all state (carousel index,
/// preview player, focus nodes) lives in the parent screen.
class CinematicHeroBlock extends StatelessWidget {
  const CinematicHeroBlock({
    super.key,
    required this.backdropImage,
    required this.heroItem,
    required this.heroWatchFocusNode,
    required this.isPreviewVideoReady,
    required this.previewPlayer,
    required this.clockTime,
    required this.onWatch,
    required this.onEpg,
    required this.onFavourite,
  });

  final ImageProvider? backdropImage;
  final NowPlayingItem? heroItem;
  final FocusNode heroWatchFocusNode;
  final bool isPreviewVideoReady;
  final PlayerManager? previewPlayer;
  final String clockTime;
  final VoidCallback? onWatch;
  final VoidCallback? onEpg;
  final VoidCallback onFavourite;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;

    return SizedBox(
      key: const Key('cinematic-hero'),
      height: 620,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: blurred backdrop / preview video.
          if (isPreviewVideoReady && previewPlayer?.activeEngine != null)
            Positioned.fill(child: previewPlayer!.activeEngine!.buildVideoWidget(fit: BoxFit.cover))
          else
            SafeBackdrop(imageProvider: backdropImage, fallbackBackground: palette.background, blurSigma: 40),

          // Layer 1: combined vignette + bottom-shade gradient.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.7, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.30),
                    Colors.black.withValues(alpha: 0.60),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // Layer 2: film grain (static, Req 9.4).
          const Positioned.fill(
            child: IgnorePointer(child: SafeFilmGrain(opacity: 0.06, child: SizedBox.expand())),
          ),

          // Layer 3: header row (Brand + Spacer + StatusBar).
          Positioned(
            top: 0,
            left: 56,
            right: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                children: [
                  const Brand(size: 36),
                  const Spacer(),
                  StatusBar(time: clockTime),
                ],
              ),
            ),
          ),

          // Layer 4: hero foreground content.
          if (heroItem != null)
            CinematicHeroContent(
              item: heroItem!,
              watchFocusNode: heroWatchFocusNode,
              onWatch: onWatch ?? () {},
              onEpg: onEpg ?? () {},
              onFavourite: onFavourite,
            )
          else
            const Positioned(
              left: 56,
              right: 56,
              bottom: 40,
              child: SizedBox(height: 4, child: LinearProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
