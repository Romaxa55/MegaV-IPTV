import 'package:flutter/material.dart';

import 'package:megav_iptv/core/layout/adaptive_scaffold.dart';
import 'package:megav_iptv/features/detail/detail_screen.dart';
import 'package:megav_iptv/features/detail/mobile/detail_mobile_screen.dart';
import 'package:megav_iptv/features/detail/providers/detail_arguments.dart';

/// Adaptive root for the channel-detail route.
///
/// Forwards [channelId] and optional [args] to the TV variant
/// ([DetailScreen]) and to the mobile variant ([DetailMobileScreen])
/// depending on viewport size, resolved by [AdaptiveScaffold].
class DetailRootScreen extends StatelessWidget {
  const DetailRootScreen({super.key, required this.channelId, this.args});

  final int channelId;
  final DetailArgs? args;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      mobile: (_) => DetailMobileScreen(channelId: channelId),
      tv: (_) => DetailScreen(channelId: channelId, args: args),
    );
  }
}
