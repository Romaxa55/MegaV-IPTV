import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/playlist/models/channel.dart';
import '../../../core/providers/providers.dart';
import '../../mobile/widgets/m_tab_bar.dart';
import 'widgets/m_hero_card.dart';
import 'widgets/m_stacked_rail.dart';
import 'widgets/m_top_bar.dart';

/// Mobile home screen — vertical scroll of meta header + hero card +
/// stacked rails, with [MTabBar] overlaid at the bottom.
///
/// Lives under `lib/features/home/mobile/` (mobile boundary — task 3.1).
/// Wired by `HomeRootScreen` via `AdaptiveScaffold` for narrow viewports.
///
/// Maps to Requirements 2.1, 2.2, 2.3, 2.4, 2.5.
class HomeMobileScreen extends ConsumerWidget {
  const HomeMobileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewPaddingTop = MediaQuery.viewPaddingOf(context).top;
    final channels = ref.watch(featuredChannelsProvider).valueOrNull ?? const <Channel>[];

    return Scaffold(
      key: const Key('home-mobile-root'),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(height: viewPaddingTop + 12),
              const MTopBar(),
              const SizedBox(height: 16),
              if (channels.isNotEmpty) MHeroCard(channels: channels.take(3).toList()),
              const SizedBox(height: 24),
              if (channels.length > 3)
                MStackedRail(title: 'Кино', emphasis: 'для вечера', items: channels.skip(3).take(8).toList()),
              const SizedBox(height: 96), // tabbar reservation
            ],
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: MTabBar()),
        ],
      ),
    );
  }
}
