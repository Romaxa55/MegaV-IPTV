import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
/// Phase 6 of the `home-editorial-redesign` spec wires every previously
/// landed atom (`EditorialBrandHeader`, `EditorialMasthead`,
/// `EditorialHeroSection`, `EditorialGenreTabsBar`, `EditorialBentoGrid`,
/// `EditorialFilmReelStrip`) into a single vertically-scrollable composition
/// inside a single [ListView]. The screen reads channels from
/// [featuredChannelsProvider] and projects them into [NowPlayingItem]
/// instances expected by the editorial atoms. When the provider is still
/// loading or empty, placeholder items keep the chrome mounted so the
/// smoke and coexistence tests can assert root keys.
///
/// **Perf contract** (Req 9.1, 9.2, 9.3, 13.3):
/// - NO [BackdropFilter], NO [ShaderMask], NO [ImageFilter.blur] in this
///   composition; downstream atoms own the same contract.
/// - The single outer [ListView] owns the scroll; every section is a
///   flat child of `ListView.children` to avoid nested scrollables.
/// - `cacheExtent`, `addAutomaticKeepAlives` and `addRepaintBoundaries`
///   mirror the cinematic-spec settings — kept in lockstep so the two
///   variants share one scroll perf profile.
///
/// Maps to Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 11.6, 13.1, 13.2 and
/// 13.3 of `home-editorial-redesign`.
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
    final bentoCells = channels.length > 3 ? channels.skip(3).take(8).toList() : const <Channel>[];

    return Scaffold(
      key: const Key('editorial-home-root'),
      body: SafeArea(
        child: ListView(
          cacheExtent: 1500,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          clipBehavior: Clip.none,
          padding: EdgeInsets.symmetric(horizontal: 56.w, vertical: 28.h),
          children: [
            const EditorialBrandHeader(),
            SizedBox(height: 24.h),
            EditorialMasthead(
              label: 'Главная',
              emphasis: 'сегодня',
              dateLine: _formatToday(),
              issueNumber: _issueNumber(),
            ),
            SizedBox(height: 24.h),
            // Hero section height: on TV 700 design-px; on narrower viewports
            // use 60% of the current window height, clamped to [280, 700.h]
            // so it always fits without overflowing the visible area.
            LayoutBuilder(
              builder: (context, constraints) {
                final windowH = MediaQuery.sizeOf(context).height;
                final heroH = (windowH * 0.60).clamp(280.0, 700.h);
                return SizedBox(
                  height: heroH,
                  child: EditorialHeroSection(
                    item: heroItem,
                    nextItem: nextItem,
                    featuredItem: featuredItem,
                    onPlay: () {},
                    onFavoriteToggle: () {},
                    onEpgOpen: () {},
                  ),
                );
              },
            ),
            SizedBox(height: 24.h),
            EditorialGenreTabsBar(
              tabs: const ['Все', 'Кино', 'Сериалы', 'Спорт', 'Новости'],
              activeIndex: 0,
              onSelected: (_) {},
            ),
            SizedBox(height: 24.h),
            EditorialSectionTitle(label: 'Кино', emphasis: 'без расписания', count: bentoCells.length),
            SizedBox(height: 16.h),
            if (bentoCells.isNotEmpty)
              EditorialBentoGrid(
                cells: bentoCells.map((c) => EditorialBentoCell(item: _toMockNow(c), cols: 1, rows: 1)).toList(),
              ),
            SizedBox(height: 24.h),
            // Film-reel strip needs a bounded height — its internal
            // `OverflowBox` would otherwise demand an infinite-height
            // constraint inside the unbounded ListView slot.
            SizedBox(
              height: 88.h,
              child: EditorialFilmReelStrip(channelCount: channels.length, activeIndex: 0, frameCount: 18),
            ),
          ],
        ),
      ),
    );
  }
}

/// Produces a Russian-locale date string in the magazine masthead idiom
/// (e.g. `9 МАЯ 2026`). Independent of system locale so the masthead
/// reads identically on every device.
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
  final m = months[now.month - 1];
  return '${now.day} $m ${now.year}';
}

/// Magazine-style issue counter — number of days elapsed since
/// 1 January 2026 (the editorial-redesign launch reference). Caps at
/// `999` to keep the masthead glyph budget at three digits.
int _issueNumber() {
  final base = DateTime(2026, 1, 1);
  final days = DateTime.now().difference(base).inDays;
  if (days < 1) return 1;
  if (days > 999) return 999;
  return days;
}

/// Wraps a [Channel] into a minimal [NowPlayingItem]. The editorial atoms
/// only read `channelId`, `channelName`, `groupTitle`, `logoUrl` and
/// `thumbnailUrl` for layout / mock display — no EPG program is required.
NowPlayingItem _toMockNow(Channel c) {
  return NowPlayingItem(
    channelId: c.id,
    channelName: c.name,
    groupTitle: c.groupTitle,
    logoUrl: c.logoUrl,
    thumbnailUrl: c.thumbnailUrl,
    program: null,
  );
}

/// Empty placeholder — used when the channels provider is still loading
/// or returned an empty list, so the chrome (hero + side cards + masthead)
/// stays mounted and exposes its keys to widget tests.
NowPlayingItem _placeholderNow(String label) {
  return NowPlayingItem(
    channelId: -1,
    channelName: label,
    groupTitle: '',
    logoUrl: null,
    thumbnailUrl: null,
    program: null,
  );
}
