import 'package:flutter/material.dart';

import 'package:megav_iptv/core/layout/adaptive_scaffold.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_home_screen.dart';

/// Adaptive root for the home route.
///
/// Selects between the mobile and TV variants of the home screen based on
/// the viewport width (see `AdaptiveScaffold` + `screenKindOf`). The mobile
/// branch is currently a stub; it will be replaced by `HomeMobileScreen`
/// in task 3.1.
class HomeRootScreen extends StatelessWidget {
  const HomeRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(mobile: (_) => const _HomeMobileStub(), tv: (_) => const CinematicHomeScreen());
  }
}

class _HomeMobileStub extends StatelessWidget {
  const _HomeMobileStub();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('home-mobile-root'),
      body: Center(child: Text('mobile home (stub)')),
    );
  }
}
