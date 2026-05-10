import 'package:flutter/material.dart';

import 'package:megav_iptv/core/layout/adaptive_scaffold.dart';
import 'package:megav_iptv/features/player/mobile/player_mobile_screen.dart';
import 'package:megav_iptv/features/player/player_screen.dart';

/// Adaptive root for the player route.
///
/// Forwards to [PlayerMobileScreen] for narrow viewports and to the existing
/// TV [PlayerScreen] otherwise, dispatched by [AdaptiveScaffold].
class PlayerRootScreen extends StatelessWidget {
  const PlayerRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(mobile: (_) => const PlayerMobileScreen(), tv: (_) => const PlayerScreen());
  }
}
