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

    // home-unified-grid-scroll: hero block заполняет высоту, которую
    // ему даёт parent (HeroAsRow с heroRowHeightDp=400 в новой
    // архитектуре, либо legacy mount-точка). Не хардкодим 620 —
    // иначе inner SizedBox(620) ломает родительский 400-dp slot.
    return SizedBox.expand(
      key: const Key('cinematic-hero'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: blurred backdrop / preview video.
          if (isPreviewVideoReady && previewPlayer?.activeEngine != null)
            Positioned.fill(child: previewPlayer!.activeEngine!.buildVideoWidget(fit: BoxFit.cover))
          else if (backdropImage != null)
            // home-unified-grid-scroll: hero — компактная 400-dp полоса с
            // чёткой обложкой канала. Прямой Image(fit: BoxFit.cover) без
            // ImageFilter.blur — это TV-perf safe (нет offscreen blur
            // round-trip, нет ImageFiltered) и визуально соответствует
            // user request "хочу картинку, а не размытое пятно".
            Positioned.fill(
              child: Image(image: backdropImage!, fit: BoxFit.cover),
            )
          else
            ColoredBox(color: palette.background),

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

          // Layer 4: hero foreground content или skeleton placeholder
          // (home-skeleton-placeholders, Wave 6) — пока featured ещё
          // грузится. Дешёвый: только серые DecoratedBox блоки, без
          // shimmer-анимации (на rtd2851a это дорого).
          if (heroItem != null)
            CinematicHeroContent(
              item: heroItem!,
              watchFocusNode: heroWatchFocusNode,
              onWatch: onWatch ?? () {},
              onEpg: onEpg ?? () {},
              onFavourite: onFavourite,
            )
          else
            const _HeroSkeletonContent(),
        ],
      ),
    );
  }
}

/// Skeleton placeholder для hero пока featured ещё не приехал.
/// Геометрия примерно повторяет реальный `CinematicHeroContent`:
/// chips-row → title 2-line → meta → action-row. Все блоки — серые
/// `DecoratedBox` без shimmer-анимации (TV-perf safe).
class _HeroSkeletonContent extends StatelessWidget {
  const _HeroSkeletonContent();

  @override
  Widget build(BuildContext context) {
    const c = Color(0x22FFFFFF);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(56, 18, 56, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chips strip
            Row(
              children: [
                _SkBox(width: 70, height: 24, color: c),
                SizedBox(width: 10),
                _SkBox(width: 120, height: 24, color: c),
                SizedBox(width: 10),
                _SkBox(width: 90, height: 24, color: c),
              ],
            ),
            SizedBox(height: 10),
            // Title 2 lines
            _SkBox(width: 720, height: 44, color: c),
            SizedBox(height: 6),
            _SkBox(width: 540, height: 44, color: c),
            SizedBox(height: 12),
            // Meta row
            _SkBox(width: 380, height: 12, color: c),
            SizedBox(height: 12),
            // Summary
            _SkBox(width: 600, height: 14, color: c),
            SizedBox(height: 6),
            _SkBox(width: 480, height: 14, color: c),
            SizedBox(height: 14),
            // Action row
            Row(
              children: [
                _SkBox(width: 220, height: 40, color: c),
                SizedBox(width: 14),
                _SkBox(width: 140, height: 40, color: c),
                SizedBox(width: 14),
                _SkBox(width: 160, height: 40, color: c),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkBox extends StatelessWidget {
  const _SkBox({required this.width, required this.height, required this.color});
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.all(Radius.circular(6))),
      child: SizedBox(width: width, height: height),
    );
  }
}
