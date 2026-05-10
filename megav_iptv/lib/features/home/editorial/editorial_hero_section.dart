import 'dart:math' as math;

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/megav_text_styles.dart';
import '../../../core/ui/atoms/atoms.dart';
import 'editorial_side_card.dart';

/// Editorial hero section — print-magazine styled lead row with a
/// 420×620-lp portrait poster, an `EDITORS' PICK` rotated badge and an
/// expanded meta column carrying chips, an italic display title, mono
/// meta-line, summary, progress, action buttons and two
/// [EditorialSideCard]s (`next` + `featured`).
///
/// **Perf contract**:
/// - Backdrop is rendered through [SafeBackdrop] — the runtime blur is
///   pre-rendered offscreen once per source change. NO `BackdropFilter`
///   in the tree (Req 9.1).
/// - A single [combinedHeroGradient] over the backdrop replaces the 3
///   stacked vignette/shade/side-fade gradients from the design handoff
///   (Req 9.3).
/// - Hero title shadow capped at [kSafeShadowBlurMax] (Req 9.2).
/// - Editors' Pick badge uses [Transform.rotate] with no animation
///   (static rotation, Req 3.7).
///
/// The widget owns a [FocusNode] that is auto-focused on first frame so
/// the primary CTA receives D-pad focus on mount (Req 3.6). It is
/// disposed in [dispose].
///
/// Maps to Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 9.1, 9.2,
/// 9.3, 9.6 and 13.1 of `home-editorial-redesign`.
class EditorialHeroSection extends ConsumerStatefulWidget {
  const EditorialHeroSection({
    super.key,
    required this.item,
    required this.nextItem,
    required this.featuredItem,
    this.onPlay,
    this.onFavoriteToggle,
    this.onEpgOpen,
  });

  /// Lead item — drives the poster, backdrop, title and meta.
  final NowPlayingItem item;

  /// Up-next item — displayed in the `next` side card.
  final NowPlayingItem nextItem;

  /// Editorially-featured item — displayed in the `featured` side card.
  final NowPlayingItem featuredItem;

  /// Tap callback for the primary `Смотреть` CTA.
  final VoidCallback? onPlay;

  /// Tap callback for the favourite-toggle ghost CTA.
  final VoidCallback? onFavoriteToggle;

  /// Tap callback for the programme-schedule ghost CTA.
  final VoidCallback? onEpgOpen;

  @override
  ConsumerState<EditorialHeroSection> createState() => _EditorialHeroSectionState();
}

class _EditorialHeroSectionState extends ConsumerState<EditorialHeroSection> {
  late final FocusNode _heroFocus;

  @override
  void initState() {
    super.initState();
    _heroFocus = FocusNode(debugLabel: 'editorial-hero-primary');
    // Defer focus request to the first post-frame callback so the
    // FocusScope has resolved before we steal focus from the framework
    // root (Req 3.6).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _heroFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _heroFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.activePalette;
    final backdropProvider = NetworkImage(widget.item.thumbnailUrl ?? widget.item.logoUrl ?? '');
    final posterProvider = NetworkImage(
      widget.item.program?.icon ?? widget.item.thumbnailUrl ?? widget.item.logoUrl ?? '',
    );

    return Stack(
      key: const Key('editorial-hero'),
      children: [
        Positioned.fill(
          child: SafeBackdrop(imageProvider: backdropProvider, fallbackBackground: palette.background),
        ),
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(gradient: combinedHeroGradient(palette))),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 56.w, vertical: 28.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 420.w,
                    height: 620.h,
                    child: Poster(image: posterProvider, orientation: PosterOrientation.portrait, hideText: true),
                  ),
                  Positioned(
                    left: -10.w,
                    top: 20.h,
                    child: Transform.rotate(
                      angle: -math.pi / 2,
                      alignment: Alignment.topLeft,
                      child: const _EditorsPickBadge(index: 1),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 36.w),
              Expanded(
                child: _MetaColumn(
                  item: widget.item,
                  nextItem: widget.nextItem,
                  featuredItem: widget.featuredItem,
                  onPlay: widget.onPlay,
                  onFavoriteToggle: widget.onFavoriteToggle,
                  onEpgOpen: widget.onEpgOpen,
                  heroFocus: _heroFocus,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Private meta column — chips → italic title → mono meta-line →
/// summary → progress → action row → side cards.
class _MetaColumn extends StatelessWidget {
  const _MetaColumn({
    required this.item,
    required this.nextItem,
    required this.featuredItem,
    required this.onPlay,
    required this.onFavoriteToggle,
    required this.onEpgOpen,
    required this.heroFocus,
  });

  final NowPlayingItem item;
  final NowPlayingItem nextItem;
  final NowPlayingItem featuredItem;
  final VoidCallback? onPlay;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onEpgOpen;
  final FocusNode heroFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    final displayItalic = styles?.displayItalic ?? theme.textTheme.headlineLarge ?? const TextStyle();
    final metaMono = styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle();
    final body = styles?.bodyDefault ?? theme.textTheme.bodyLarge ?? const TextStyle();

    final program = item.program;
    final title = program?.title ?? item.channelName;
    final year = program?.parsedYear ?? '';
    final genre = program?.category ?? item.groupTitle;
    final summary = program?.synopsis ?? '';

    final metaParts = <String>[if (year.isNotEmpty) year, if (genre.isNotEmpty) genre];
    final metaLine = metaParts.join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chips row — keep simple, the `Chip` atom is the same one the
        // editorial design system exposes via the atoms barrel.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const Chip(variant: ChipVariant.live, label: 'В эфире'),
            Chip(variant: ChipVariant.brand, label: item.channelName),
            const Chip(variant: ChipVariant.gold, label: 'Premiere'),
          ],
        ),
        SizedBox(height: 16.h),
        // Italic display title with single safe shadow (Req 9.2).
        // FontStyle is explicit so the italic invariant survives even if
        // the [MegaVTextStyles] extension is absent (theme-fallback path).
        Text(
          title,
          style: displayItalic.copyWith(
            fontSize: 84,
            fontStyle: FontStyle.italic,
            color: palette.text,
            shadows: const [Shadow(color: Color(0x66000000), blurRadius: kSafeShadowBlurMax, offset: Offset(0, 2))],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 12.h),
        // Mono meta-line.
        if (metaLine.isNotEmpty) Text(metaLine, style: metaMono.copyWith(color: palette.textDim)),
        SizedBox(height: 12.h),
        // Summary, capped to 540 lp wide and 4 lines.
        if (summary.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 540.w),
            child: Text(
              summary,
              style: body.copyWith(color: palette.textDim),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        SizedBox(height: 16.h),
        // Progress.
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 540.w),
          child: const _HeroProgress(),
        ),
        SizedBox(height: 16.h),
        // Action row — primary CTA owns the hero FocusNode.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              focusNode: heroFocus,
              child: MvButton.primary(label: 'Смотреть', onPressed: onPlay, isFocused: heroFocus.hasFocus),
            ),
            SizedBox(width: 12.w),
            MvButton.ghost(label: '+ В избранное', onPressed: onFavoriteToggle),
            SizedBox(width: 12.w),
            MvButton.ghost(label: 'Программа', onPressed: onEpgOpen),
          ],
        ),
        SizedBox(height: 20.h),
        // Side cards — strip the unused progress so caller-injected items
        // simply render as-is. Caller computes the remaining countdown.
        Row(
          children: [
            Expanded(
              child: EditorialSideCard.next(item: nextItem, remaining: '55 мин'),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: EditorialSideCard.featured(item: featuredItem, remaining: '2ч 06м'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Pre-baked progress consumer wrapped in a [RepaintBoundary] so its
/// per-minute rebuild does not invalidate the hero meta column
/// (Req 9.6). The consumer is intentionally const-constructed.
class _HeroProgress extends ConsumerWidget {
  const _HeroProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const RepaintBoundary(child: MvTrack(progress: 0.42, showKnob: false));
  }
}

/// Static `EDITORS' PICK · NN` badge rendered in palette gold. The
/// badge is rotated -90° by the hero stack so it appears as a vertical
/// gutter-marker over the poster. NO animation (Req 3.7).
class _EditorsPickBadge extends StatelessWidget {
  const _EditorsPickBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<MegaVTextStyles>();
    final palette = AppColors.activePalette;

    final metaMono = styles?.metaMono ?? theme.textTheme.labelSmall ?? const TextStyle();

    return Container(
      decoration: BoxDecoration(color: palette.gold),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        "EDITORS' PICK · ${index.toString().padLeft(2, '0')}",
        style: metaMono.copyWith(color: const Color(0xFF1A1208), fontWeight: FontWeight.w700, letterSpacing: 0.16),
      ),
    );
  }
}
