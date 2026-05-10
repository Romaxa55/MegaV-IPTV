// SearchScreen — top-level route widget for `/search`.
//
// Two-pane layout:
//   * Left pane — header + `SearchInput` + `CyrillicKeyboard`.
//     Width is adaptive: on TV (>=1280) fixed 360 design-px; on narrower
//     viewports the left pane takes min(360.w, 42% of window width) so the
//     keyboard always has room and never overflows.
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

import 'package:megav_iptv/core/layout/screen_kind.dart';

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
    final kind = screenKindOf(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // On TV the left pane is 360 design-pixels (already scaled by
            // ScreenUtil to real pixels). On tablet/mobile we cap at 42% of
            // the available width so the keyboard is never squeezed below
            // its minimum comfortable size.  On very narrow viewports
            // (<600 px) we switch to a full-width single-column layout so
            // the keyboard is reachable at all.
            final availableWidth = constraints.maxWidth;
            if (kind == ScreenKind.mobile || availableWidth < 500) {
              // Single-column: keyboard on top, results below, scrollable.
              return const Column(
                children: [
                  _LeftPane(singleColumn: true),
                  Expanded(child: SearchResultsGrid()),
                ],
              );
            }

            // Two-pane: left pane width adapts to viewport.
            final leftWidth = kind == ScreenKind.tv ? 360.w : (availableWidth * 0.42).clamp(260.0, 360.w);

            return Row(
              children: [
                SizedBox(width: leftWidth, child: const _LeftPane()),
                const Expanded(child: SearchResultsGrid()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LeftPane extends ConsumerWidget {
  const _LeftPane({this.singleColumn = false});

  /// When true the pane fills full width and the keyboard is not Expanded
  /// (the parent Column controls height distribution instead).
  final bool singleColumn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchControllerProvider);
    final notifier = ref.read(searchControllerProvider.notifier);

    final keyboard = CyrillicKeyboard(
      onKeyPressed: notifier.onKeyPressed,
      onExitRight: () => FocusScope.of(context).focusInDirection(TraversalDirection.right),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: singleColumn ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Inline header — atom SectionTitle uses Spacer which overflows
          // narrow LeftPane (360w on TV, less on debug macOS window).
          DefaultTextStyle(
            style: Theme.of(context).textTheme.headlineSmall ?? const TextStyle(fontSize: 22),
            child: const Row(
              children: [
                Text('Поиск'),
                SizedBox(width: 6),
                Text('найти', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          SearchInput(query: state.query),
          SizedBox(height: 16.h),
          // In two-pane mode the keyboard expands to fill remaining height;
          // in single-column mode it sits at its intrinsic size (MainAxisSize.min).
          if (singleColumn) keyboard else Expanded(child: keyboard),
        ],
      ),
    );
  }
}
