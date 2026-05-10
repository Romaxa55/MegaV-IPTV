import 'package:flutter/material.dart';

import 'package:megav_iptv/core/layout/adaptive_scaffold.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_home_screen.dart';
import 'package:megav_iptv/features/home/mobile/home_mobile_screen.dart';

/// Adaptive root for the home route.
///
/// Selects between the mobile and TV variants of the home screen based on
/// the viewport width (see `AdaptiveScaffold` + `screenKindOf`). Mobile uses
/// [HomeMobileScreen] (Phase 3); TV keeps the existing [CinematicHomeScreen].
class HomeRootScreen extends StatelessWidget {
  const HomeRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(mobile: (_) => const HomeMobileScreen(), tv: (_) => const CinematicHomeScreen());
  }
}
