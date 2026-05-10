// SearchScreen — top-level route widget for `/search`.
//
// Two-pane layout:
//   * Left pane (360 dp wide) — header + `SearchInput` + `CyrillicKeyboard`.
//   * Right pane (Expanded) — `SearchResultsGrid` reacting to
//     `searchControllerProvider`.
//
// Stateless `ConsumerWidget` per Req 10.5 — every piece of mutable state
// lives inside `SearchController`. Focus exit from the keyboard's right
// edge transfers via `FocusScope.of(context).focusInDirection(...)`,
// allowing the system to pick the closest focusable in the right pane.
//
// Maps to Requirements 1.5, 10.5, 11.1, 11.2, 11.3, 11.4, 11.5.

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:megav_iptv/core/ui/atoms/atoms.dart';

import 'state/search_controller.dart';
import 'widgets/cyrillic_keyboard.dart';
import 'widgets/search_input.dart';
import 'widgets/search_results_grid.dart';

/// Search screen mounted at the `/search` route.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(width: 360.w, child: const _LeftPane()),
            const Expanded(child: SearchResultsGrid()),
          ],
        ),
      ),
    );
  }
}

class _LeftPane extends ConsumerWidget {
  const _LeftPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchControllerProvider);
    final notifier = ref.read(searchControllerProvider.notifier);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(title: 'Поиск', emphasis: 'найти'),
          SizedBox(height: 16.h),
          SearchInput(query: state.query),
          SizedBox(height: 16.h),
          Expanded(
            child: CyrillicKeyboard(
              onKeyPressed: notifier.onKeyPressed,
              onExitRight: () => FocusScope.of(context).focusInDirection(TraversalDirection.right),
            ),
          ),
        ],
      ),
    );
  }
}
