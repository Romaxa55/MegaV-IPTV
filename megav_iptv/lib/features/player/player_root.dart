import 'package:flutter/material.dart';

import 'package:megav_iptv/core/layout/adaptive_scaffold.dart';
import 'package:megav_iptv/features/player/player_screen.dart';

/// Adaptive root for the player route.
///
/// Mobile branch is a stub for now (replaced in a later mobile-player task);
/// TV branch mounts the existing [PlayerScreen] unchanged.
class PlayerRootScreen extends StatelessWidget {
  const PlayerRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(mobile: (_) => const _PlayerMobileStub(), tv: (_) => const PlayerScreen());
  }
}

class _PlayerMobileStub extends StatelessWidget {
  const _PlayerMobileStub();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('player-mobile-root'),
      body: Center(child: Text('mobile player (stub)')),
    );
  }
}
