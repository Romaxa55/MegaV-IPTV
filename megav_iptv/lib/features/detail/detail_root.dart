import 'package:flutter/material.dart';

import 'package:megav_iptv/core/layout/adaptive_scaffold.dart';
import 'package:megav_iptv/features/detail/detail_screen.dart';
import 'package:megav_iptv/features/detail/providers/detail_arguments.dart';

/// Adaptive root for the channel-detail route.
///
/// Forwards [channelId] and optional [args] to the TV variant
/// ([DetailScreen]) and renders a stub for mobile until task 3.x lands a
/// real mobile detail screen.
class DetailRootScreen extends StatelessWidget {
  const DetailRootScreen({super.key, required this.channelId, this.args});

  final int channelId;
  final DetailArgs? args;

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      mobile: (_) => const _DetailMobileStub(),
      tv: (_) => DetailScreen(channelId: channelId, args: args),
    );
  }
}

class _DetailMobileStub extends StatelessWidget {
  const _DetailMobileStub();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('detail-mobile-root'),
      body: Center(child: Text('mobile detail (stub)')),
    );
  }
}
