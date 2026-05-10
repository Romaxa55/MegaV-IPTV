import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Editorial Home — print-magazine styled variant of the Home surface.
///
/// This is the empty skeleton landed by task 1.2 of the
/// `home-editorial-redesign` spec. Subsequent phases (2-5) populate the
/// `SafeArea` body with brand header, masthead, hero, side card, lead
/// rail and supporting rails.
///
/// The root widget exposes [Key]`('editorial-home-root')` so the smoke
/// test (and the entry-switch coexistence test in phase 6) can assert
/// the screen mounted without exception.
class EditorialHomeScreen extends ConsumerStatefulWidget {
  const EditorialHomeScreen({super.key});

  @override
  ConsumerState<EditorialHomeScreen> createState() => _EditorialHomeScreenState();
}

class _EditorialHomeScreenState extends ConsumerState<EditorialHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: SizedBox.shrink(key: Key('editorial-home-root'))),
    );
  }
}
