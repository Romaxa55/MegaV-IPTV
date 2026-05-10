import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/playlist/models/now_playing.dart';
import '../../../core/providers/providers.dart';
import 'editorial_bento_card.dart';
import 'editorial_bento_grid.dart';
import 'editorial_brand_header.dart';
import 'editorial_film_reel_strip.dart';
import 'editorial_genre_tabs_bar.dart';
import 'editorial_hero_section.dart';
import 'editorial_masthead.dart';
import 'editorial_section_title.dart';

/// Editorial Home — print-magazine styled variant of the Home surface.
///
/// JSX reference: `home-editorial.jsx`.
///
/// Layout matches JSX structure:
/// 1. `Header` — Brand + StatusBar (56px horizontal padding).
/// 2. Masthead block — `padding: "8px 56px 28px"`.
/// 3. Hero row — `padding: "0 56px 40px"`.
/// 4. `GenreTabs` — full width strip.
/// 5. Bento section — `padding: "32px 56px"`.
/// 6. Film reel strip — `padding: "12px 56px 0"`.
///
/// The ListView itself has `padding: EdgeInsets.zero`; each child owns its
/// own horizontal padding of 56 lp. This mirrors the JSX where each section
/// has `padding: "... 56px"`.
///
/// Perf contract (Req 9.1, 9.2, 9.3, 13.3):
/// - NO BackdropFilter, NO ShaderMask, NO ImageFilter.blur in this file.
/// - Single outer ListView; every section is a flat child.
/// - cacheExtent / addAutomaticKeepAlives / addRepaintBoundaries match
///   cinematic-spec settings.
///
/// Maps to Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 11.6, 13.1, 13.2, 13.3.
class EditorialHomeScreen extends ConsumerStatefulWidget {
  const EditorialHomeScreen({super.key});

  @override
  ConsumerState<EditorialHomeScreen> createState() => _EditorialHomeScreenState();
}

class _EditorialHomeScreenState extends ConsumerState<EditorialHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(featuredChannelsProvider).valueOrNull ?? const <Channel>[];

    final heroItem = channels.isNotEmpty ? _toMockNow(channels[0]) : _placeholderNow('hero');
    final nextItem = channels.length > 1 ? _toMockNow(channels[1]) : _placeholderNow('next');
    final featuredItem = channels.length > 2 ? _toMockNow(channels[2]) : _placeholderNow('featured');
    final bentoChannels = channels.length > 3 ? channels.skip(3).take(8).toList() : const <Channel>[];

    // Bento layout mirrors JSX: [2×2, 2×1, 2×1, 1×1, 1×1, 2×1, 2×1, 2×1].
    final bentoCells = _buildBentoCells(bentoChannels);

    return Scaffold(
      key: const Key('editorial-home-root'),
      body: SafeArea(
        child: ListView(
          cacheExtent: 1500,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          clipBehavior: Clip.none,
          padding: EdgeInsets.zero,
          children: [
            // ── Header: Brand + StatusBar ───────────────────────────────
            // JSX: <Header /> inside mv-header → padding: 28px 56px.
            const Padding(padding: EdgeInsets.fromLTRB(56, 28, 56, 28), child: EditorialBrandHeader()),

            // ── Masthead block ──────────────────────────────────────────
            // JSX: padding "8px 56px 28px", borderBottom hairline.
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 8, 56, 0),
              child: EditorialMasthead(
                label: 'Главная',
                emphasis: 'сегодня',
                dateLine: _formatToday(),
                issueNumber: _issueNumber(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Hero row ────────────────────────────────────────────────
            // JSX: padding "0 56px 40px", grid auto sized.
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 56, 40),
              child: EditorialHeroSection(
                item: heroItem,
                nextItem: nextItem,
                featuredItem: featuredItem,
                onPlay: () {},
                onFavoriteToggle: () {},
                onEpgOpen: () {},
              ),
            ),

            // ── Genre tabs ──────────────────────────────────────────────
            // JSX: <GenreTabs> — full width strip with borders.
            EditorialGenreTabsBar(
              tabs: const ['В эфире', 'Кино', 'Сериалы', 'Спорт', 'Новости', 'Дети', 'Музыка'],
              activeIndex: 1,
              onSelected: (_) {},
            ),

            // ── Bento grid section ──────────────────────────────────────
            // JSX: padding "32px 56px", SectionTitle + grid.
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: EditorialSectionTitle(label: 'Кино', emphasis: 'без расписания', count: bentoChannels.length),
            ),
            const SizedBox(height: 16),
            if (bentoCells.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: EditorialBentoGrid(cells: bentoCells),
              ),

            // ── Film reel strip ─────────────────────────────────────────
            // JSX: padding "12px 56px 0", height ~48px.
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 56, 0),
              child: SizedBox(
                height: 48,
                child: EditorialFilmReelStrip(channelCount: channels.length, activeIndex: 0, frameCount: 18),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

/// Maps [bentoChannels] to [EditorialBentoCell] list with the JSX bento
/// layout: [2×2, 2×1, 2×1, 1×1, 1×1, 2×1, 2×1, 2×1].
/// Falls back to 1×1 when insufficient items.
List<EditorialBentoCell> _buildBentoCells(List<Channel> channels) {
  if (channels.isEmpty) return const [];
  final spans = <(int, int)>[
    (2, 2), // idx 0 — big
    (2, 1), // idx 1
    (2, 1), // idx 2
    (1, 1), // idx 3
    (1, 1), // idx 4
    (2, 1), // idx 5
    (2, 1), // idx 6
    (2, 1), // idx 7
  ];
  final result = <EditorialBentoCell>[];
  for (var i = 0; i < channels.length && i < spans.length; i++) {
    final (cols, rows) = spans[i];
    result.add(EditorialBentoCell(item: _toMockNow(channels[i]), cols: cols, rows: rows, live: i == 0));
  }
  return result;
}

String _formatToday() {
  const months = <String>[
    'ЯНВАРЯ',
    'ФЕВРАЛЯ',
    'МАРТА',
    'АПРЕЛЯ',
    'МАЯ',
    'ИЮНЯ',
    'ИЮЛЯ',
    'АВГУСТА',
    'СЕНТЯБРЯ',
    'ОКТЯБРЯ',
    'НОЯБРЯ',
    'ДЕКАБРЯ',
  ];
  final now = DateTime.now();
  return '${now.day} ${months[now.month - 1]} ${now.year}';
}

int _issueNumber() {
  final base = DateTime(2026, 1, 1);
  final days = DateTime.now().difference(base).inDays;
  if (days < 1) return 1;
  if (days > 999) return 999;
  return days;
}

NowPlayingItem _toMockNow(Channel c) => NowPlayingItem(
  channelId: c.id,
  channelName: c.name,
  groupTitle: c.groupTitle,
  logoUrl: c.logoUrl,
  thumbnailUrl: c.thumbnailUrl,
  program: null,
);

NowPlayingItem _placeholderNow(String label) =>
    NowPlayingItem(channelId: -1, channelName: label, groupTitle: '', logoUrl: null, thumbnailUrl: null, program: null);
