import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cinematic variant of the home screen — full skeleton lands across
/// phases 2–4 of `home-cinematic-redesign` impl. This file currently
/// owns the route entry + root key required by Req 1.x and 13.1; the
/// subtree (hero, genre tabs, rails, live strip, remote hint footer) is
/// added by subsequent tasks.
class CinematicHomeScreen extends ConsumerStatefulWidget {
  const CinematicHomeScreen({super.key});

  @override
  ConsumerState<CinematicHomeScreen> createState() => _CinematicHomeScreenState();
}

class _CinematicHomeScreenState extends ConsumerState<CinematicHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: SizedBox.shrink(key: Key('cinematic-home-root'))),
    );
  }
}
