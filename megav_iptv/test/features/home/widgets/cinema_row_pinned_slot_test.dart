// Pinned-Slot Invariant verifiable contract (home-grid-stability-pass spec).
//
// Three clauses are tested:
//   1. Middle traversal — focused tile screen-space stays put (Δ ≤ 1.0 dp)
//      when index transitions through the middle of the row.
//   2. Leading-edge clamp — focused tile 0 → scrollOffset = 0.
//   3. Trailing-edge clamp — focused tile N-1 → scrollOffset = maxScrollExtent.
//
// All harness wiring mirrors cinema_row_scroll_test.dart so the two files
// can evolve together. Helpers (_item, _harness, _tileFocusNode) are
// intentionally local — keeping them duplicated rather than sharing a
// fixture file avoids cross-test boundary tangles.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/features/home/widgets/_grid_tokens.dart';
import 'package:megav_iptv/features/home/widgets/cinema_row.dart';

NowPlayingItem _item(int id) => NowPlayingItem(
      channelId: id,
      channelName: 'Channel $id',
      groupTitle: 'Movies',
      logoUrl: null,
      thumbnailUrl: null,
      program: null,
    );

Widget _harness({required Widget child, required FocusNode externalNode}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ScreenUtilInit(
      designSize: const Size(1920, 1080),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Column(
            children: [
              Focus(
                focusNode: externalNode,
                child: const SizedBox(width: 100, height: 100),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

FocusNode _tileFocusNode(WidgetTester tester, int index) {
  final focusFinder = find.byWidgetPredicate(
    (w) =>
        w is Focus &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.endsWith('_$index'),
  );
  expect(
    focusFinder,
    findsWidgets,
    reason: 'Expected at least one Focus widget for tile index $index',
  );
  final tileFocusState = tester.state<State<Focus>>(focusFinder.first);
  final dynamic state = tileFocusState;
  return state.focusNode as FocusNode;
}

/// Pixel-space position of the focused tile (the card-key Padded box).
Offset _tileScreenPos(WidgetTester tester, int channelId, int index) {
  final box = tester.renderObject<RenderBox>(
    find.byKey(ValueKey('card_${channelId}_$index')),
  );
  return box.localToGlobal(Offset.zero);
}

void main() {
  group('Pinned-Slot Invariant', () {
    testWidgets(
      'middle traversal — focused tile screen-space stays put (Δ ≤ 1.0 dp)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 10 items: enough so that tiles 2..7 are all in the "middle"
        // region where both leading- and trailing-edge clamps are inactive.
        final items = List.generate(10, (i) => _item(100 + i));
        final externalNode = FocusNode();

        await tester.pumpWidget(
          _harness(
            externalNode: externalNode,
            child: CinemaRow(
              title: 'Test',
              items: items,
              onItemTap: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Walk focus 0 → 1 → 2 to bring tile 2 into the build tree.
        // pumpAndSettle is more robust here than a hand-rolled pump cadence:
        // _scrollFocusedTileToLeadingEdge dispatches through postFrameCallback
        // → animateTo, and the animation may not finish in a single pump
        // window. pumpAndSettle keeps pumping until no more frames are
        // scheduled.
        for (var i = 0; i <= 2; i++) {
          _tileFocusNode(tester, i).requestFocus();
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }

        // Snapshot tile-2 screen X (Y can wobble within ±1 dp due to Align(bottomCenter)
        // when row height re-computes; the invariant only constrains X).
        double prevX = _tileScreenPos(tester, items[2].channelId, 2).dx;

        // Step 2 → 3 → 4 → 5 → 6. The FOCUSED tile's screen-space X must
        // stay within 1.0 dp of the previous step's X (the grid stays put
        // while items slide through the pinned slot).
        for (var i = 3; i <= 6; i++) {
          _tileFocusNode(tester, i).requestFocus();
          await tester.pumpAndSettle(const Duration(seconds: 1));

          final newX = _tileScreenPos(tester, items[i].channelId, i).dx;
          final drift = (prevX - newX).abs();
          expect(
            drift,
            lessThanOrEqualTo(1.0),
            reason:
                'Focused tile screen-space X drifted by ${drift.toStringAsFixed(2)} dp '
                'between index ${i - 1} → $i (tolerance: 1.0 dp). '
                'prevX=${prevX.toStringAsFixed(2)} newX=${newX.toStringAsFixed(2)}',
          );
          prevX = newX;
        }

        externalNode.dispose();
      },
    );

    testWidgets(
      'leading-edge clamp — focused tile 0 → scrollOffset stays at 0',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final items = List.generate(10, (i) => _item(200 + i));
        final externalNode = FocusNode();

        await tester.pumpWidget(
          _harness(
            externalNode: externalNode,
            child: CinemaRow(
              title: 'Test',
              items: items,
              onItemTap: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Focus tile 0 explicitly.
        _tileFocusNode(tester, 0).requestFocus();
        await tester.pump();
        await tester.pump();
        await tester.pump(
          GridTokens.scrollAnimation + const Duration(milliseconds: 50),
        );

        final scrollable = tester.state<ScrollableState>(
          find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
          ),
        );
        final offset = scrollable.position.pixels;

        expect(
          offset,
          equals(0.0),
          reason:
              'Leading-edge clamp violated: scrollOffset = ${offset.toStringAsFixed(2)} '
              '(expected 0). With pinnedSlotIdx = ${GridTokens.pinnedSlotIdx}, '
              'tile 0 → targetOffset = (0 - ${GridTokens.pinnedSlotIdx}) * cardStride < 0 → clamped to 0.',
        );

        externalNode.dispose();
      },
    );

    testWidgets(
      'trailing-edge clamp — focused tile N-1 → scrollOffset = maxScrollExtent',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final items = List.generate(10, (i) => _item(300 + i));
        final externalNode = FocusNode();

        await tester.pumpWidget(
          _harness(
            externalNode: externalNode,
            child: CinemaRow(
              title: 'Test',
              items: items,
              onItemTap: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Walk focus across all tiles to materialise tile N-1 in the
        // lazy ListView build tree.
        for (var i = 0; i < items.length; i++) {
          _tileFocusNode(tester, i).requestFocus();
          await tester.pump();
          await tester.pump();
          await tester.pump(
            GridTokens.scrollAnimation + const Duration(milliseconds: 50),
          );
        }

        final scrollable = tester.state<ScrollableState>(
          find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
          ),
        );
        final offset = scrollable.position.pixels;
        final maxOffset = scrollable.position.maxScrollExtent;

        // Tolerance ±1.0 dp absorbs flutter_screenutil density rounding.
        expect(
          (offset - maxOffset).abs(),
          lessThanOrEqualTo(1.0),
          reason:
              'Trailing-edge clamp violated: scrollOffset = ${offset.toStringAsFixed(2)}, '
              'maxScrollExtent = ${maxOffset.toStringAsFixed(2)} '
              '(expected equal within 1.0 dp). For tile ${items.length - 1}, '
              'targetOffset = (${items.length - 1} - ${GridTokens.pinnedSlotIdx}) * cardStride '
              '> maxScrollExtent → clamped to maxScrollExtent.',
        );

        externalNode.dispose();
      },
    );
  });
}
