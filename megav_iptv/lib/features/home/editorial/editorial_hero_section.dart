import 'dart:math' as math;

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    // Hero row — portrait poster (420×620) + expanded meta column.
    // JSX: grid "auto 1fr", gap 36, padding "0 56px 40px".
    // Backdrop + gradient are painted behind the row via a Stack that sizes
    // itself to the row's intrinsic height (no forced SizedBox height).
    final heroRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              // JSX: Poster w=420 h=620.
              width: 420,
              height: 620,
              child: Poster(image: posterProvider, orientation: PosterOrientation.portrait, hideText: true),
            ),
            Positioned(
              left: -10,
              top: 20,
              child: Transform.rotate(
                angle: -math.pi / 2,
                alignment: Alignment.topLeft,
                child: const _EditorsPickBadge(index: 1),
              ),
            ),
          ],
        ),
        const SizedBox(width: 36),
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
    );

    return Stack(
      key: const Key('editorial-hero'),
      children: [
        // Backdrop fills the Stack — Stack sizes itself to heroRow's height.
        Positioned.fill(
          child: SafeBackdrop(imageProvider: backdropProvider, fallbackBackground: palette.background),
        ),
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(gradient: combinedHeroGradient(palette))),
        ),
        heroRow,
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
        const SizedBox(height: 16),
        // Italic display title 84sp — JSX: fontSize: 84, fontStyle: italic.
        Text(
          title,
          style: displayItalic.copyWith(
            fontSize: 84,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
            height: 0.95,
            letterSpacing: -0.02 * 84,
            color: palette.text,
            shadows: const [Shadow(color: Color(0x66000000), blurRadius: kSafeShadowBlurMax, offset: Offset(0, 2))],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        // Mono meta-line — JSX: fontSize: 12, letterSpacing: "0.14em", uppercase.
        if (metaLine.isNotEmpty)
          Text(
            metaLine.toUpperCase(),
            style: metaMono.copyWith(fontSize: 12, letterSpacing: 0.14 * 12, color: palette.textDim),
          ),
        const SizedBox(height: 12),
        // Summary — JSX: fontSize: 17, lineHeight: 1.55, maxWidth: 540.
        if (summary.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Text(
              summary,
              style: body.copyWith(fontSize: 17, height: 1.55, color: palette.textDim),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 16),
        // Progress — JSX: mv-track maxWidth: 480, mv-ticks below.
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: const _HeroProgress()),
        const SizedBox(height: 16),
        // Action row — JSX: gap 12px, primary + 2 ghost buttons.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Focus(
              focusNode: heroFocus,
              child: MvButton.primary(label: 'Смотреть', onPressed: onPlay, isFocused: heroFocus.hasFocus),
            ),
            const SizedBox(width: 12),
            MvButton.ghost(label: '+ В избранное', onPressed: onFavoriteToggle),
            const SizedBox(width: 12),
            MvButton.ghost(label: 'Программа', onPressed: onEpgOpen),
          ],
        ),
        const SizedBox(height: 20),
        // Side cards — JSX: gridTemplateColumns "1fr 1fr", gap 14, marginTop 8.
        Row(
          children: [
            Expanded(
              child: EditorialSideCard.next(item: nextItem, remaining: '55 мин'),
            ),
            const SizedBox(width: 14),
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
