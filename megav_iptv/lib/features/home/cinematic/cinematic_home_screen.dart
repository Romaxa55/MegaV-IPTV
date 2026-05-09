import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/atoms/atoms.dart';
import 'cinematic_dual_rail.dart';
import 'cinematic_genre_tabs_bar.dart';
import 'cinematic_hero_section.dart';
import 'cinematic_live_strip.dart';
import 'cinematic_rail.dart';
import 'cinematic_remote_hint_footer.dart';
import 'cinematic_section_title.dart';

/// Cinematic variant of the home screen — composes all phase 2-4 widgets
/// into a vertically scrollable layout.
///
/// Maps to Requirements 1.1-1.5, 2.7, 9.1-9.4, 13.1.
class CinematicHomeScreen extends ConsumerStatefulWidget {
  const CinematicHomeScreen({super.key});

  @override
  ConsumerState<CinematicHomeScreen> createState() => _CinematicHomeScreenState();
}

class _CinematicHomeScreenState extends ConsumerState<CinematicHomeScreen> {
  final FocusNode _heroFocus = FocusNode(debugLabel: 'cinematic-hero-watch');

  @override
  void initState() {
    super.initState();
    // Req 2.7 — initially focused on mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _heroFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _heroFocus.dispose();
    super.dispose();
  }

  // Mock data for Phase 5 integration. Real wiring lands in a follow-up
  // when this screen is opened from production routing.
  List<CinematicRailItem> _mockItems(int count) =>
      List.generate(count, (i) => CinematicRailItem(id: 'mock-$i', title: 'Item $i', imageProvider: null));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SizedBox.expand(
          key: const Key('cinematic-home-root'),
          child: ListView(
            cacheExtent: 1500,
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: true,
            clipBehavior: Clip.none,
            padding: EdgeInsets.zero,
            children: [
              // Top bar — Brand + (optional StatusBar)
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 16, 32, 8),
                child: Row(
                  children: [
                    Brand(size: 40),
                    Spacer(),
                    StatusBar(city: 'Moscow', tempC: 5, time: '20:30'),
                  ],
                ),
              ),

              // 2. Genre tabs
              const CinematicGenreTabsBar(labels: ['Все', 'Кино', 'Сериалы', 'Спорт', 'Новости'], activeIndex: 0),

              // 3. Hero section
              CinematicHeroSection(
                title: 'Featured Title',
                channelName: 'Channel One',
                programLabel: 'Now: Featured Program',
                onWatch: () {},
              ),

              // 4. Live эфир — section title + landscape rail
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 24, 32, 12),
                child: CinematicSectionTitle(label: 'Сейчас в', emphasis: 'эфире'),
              ),
              CinematicDualRail.landscape(items: _mockItems(8)),

              // 5. Live strip
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CinematicLiveStrip(currentTitle: 'Now playing', nextLabel: 'Next at 21:00', progress: 0.5),
              ),

              // 6. Catalog — section title + portrait rail
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 24, 32, 12),
                child: CinematicSectionTitle(label: 'Фильмы', emphasis: '· каталог'),
              ),
              CinematicDualRail.portrait(items: _mockItems(8)),

              // 7. Remote hint footer
              const Padding(padding: EdgeInsets.only(top: 24), child: CinematicRemoteHintFooter()),
            ],
          ),
        ),
      ),
    );
  }
}
