import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mobile/widgets/m_live_dot.dart';
import 'widgets/m_player_controls.dart';
import 'widgets/m_swipe_hint.dart';

/// Mobile-only player screen.
///
/// Rendered by [PlayerRootScreen] via [AdaptiveScaffold] for narrow
/// viewports (Phase 5 task 5.1 of the mobile-adaptive-layout spec).
///
/// Composition:
///  - Black video-surface placeholder (would consume `playerUiStateProvider`
///    read-only in the production wiring).
///  - Full-bleed [GestureDetector] capturing horizontal swipes that switch
///    the current channel. The first detected swipe dismisses the hint.
///  - Top-left [MLiveDot] anchored to the safe area.
///  - Bottom-aligned [MPlayerControls] (frosted glass).
///  - [MSwipeHint] in the top-right while [_swipeHintDismissed] is false.
class PlayerMobileScreen extends ConsumerStatefulWidget {
  const PlayerMobileScreen({super.key});

  @override
  ConsumerState<PlayerMobileScreen> createState() => _PlayerMobileScreenState();
}

class _PlayerMobileScreenState extends ConsumerState<PlayerMobileScreen> {
  bool _swipeHintDismissed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        key: const Key('player-mobile-root'),
        children: [
          // Video surface placeholder.
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          // Swipe gesture layer.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final velocity = details.velocity.pixelsPerSecond.dx.abs();
                if (velocity > 500 || details.primaryVelocity == null) {
                  // Switch channel — placeholder; would call into the
                  // player service in the production wiring.
                  if (!_swipeHintDismissed) {
                    setState(() => _swipeHintDismissed = true);
                  }
                }
              },
            ),
          ),
          Positioned(top: MediaQuery.viewPaddingOf(context).top + 16, left: 16, child: const MLiveDot()),
          const Positioned(bottom: 0, left: 0, right: 0, child: MPlayerControls()),
          if (!_swipeHintDismissed) const Positioned(top: 60, right: 16, child: MSwipeHint()),
        ],
      ),
    );
  }
}
