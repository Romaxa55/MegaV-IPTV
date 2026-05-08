import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/features/home/widgets/cinema_row.dart';

NowPlayingItem _item(int id) => NowPlayingItem(
      channelId: id,
      channelName: 'Channel $id',
      groupTitle: 'Movies',
      logoUrl: null,
      thumbnailUrl: null,
      program: null,
    );

/// Wraps the [child] in a runtime-realistic harness so screenutil resolves
/// `.w/.h/.sp` to identity scale (designSize == runtime size).
///
/// IMPORTANT: must be paired with `tester.binding.setSurfaceSize(Size(1920, 1080))`
/// so the actual render surface matches the MediaQuery override, otherwise
/// ListView culls tiles that fall outside the (default 800x600) viewport.
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
              // External focusable widget — used to move focus OUT of the row.
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

/// Returns the [FocusNode] of the tile-level `Focus` widget at [index].
///
/// Each tile is wrapped in `Focus(key: ValueKey('<channelId>_<index>'), ...)`
/// in `cinema_row.dart`. To request focus on it from a test, we need the
/// underlying [FocusNode]. `Focus.of(context)` registers an inherited
/// dependency on `_FocusInheritedScope`, and registering that dependency
/// from outside the Focus subtree triggers a framework `is_descendant`
/// assertion when the scope later notifies clients.
///
/// To avoid that, we read the public `focusNode` getter on `Focus`'s
/// `State` via `tester.state<State<Focus>>(...)`. The framework's private
/// `_FocusState` exposes `focusNode` as a public getter; using `dynamic`
/// dispatch keeps us off the private name.
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
  // Cast to dynamic so we can call the (private-class, public-named)
  // `focusNode` getter without naming the private type.
  final dynamic state = tileFocusState;
  final FocusNode node = state.focusNode as FocusNode;

  expect(
    node.context,
    isNotNull,
    reason: 'Resolved tile FocusNode must still be attached to a BuildContext',
  );
  return node;
}

void main() {
  testWidgets(
    'fast traversal across tiles within 400 ms does not dispatch onItemFocus(item)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final items = [_item(1), _item(2), _item(3)];
      final received = <NowPlayingItem?>[];
      final externalNode = FocusNode();

      await tester.pumpWidget(
        _harness(
          externalNode: externalNode,
          child: CinemaRow(
            title: 'Test',
            items: items,
            onItemTap: (_) {},
            onItemFocus: (item) => received.add(item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Capture tile FocusNodes once before any focus traversal — keys keep
      // them stable across rebuilds.
      final tile0 = _tileFocusNode(tester, 0);
      final tile1 = _tileFocusNode(tester, 1);
      final tile2 = _tileFocusNode(tester, 2);

      // Move through tile 0 → 1 → 2 with < 400ms dwell each.
      tile0.requestFocus();
      await tester.pump(const Duration(milliseconds: 50));
      tile1.requestFocus();
      await tester.pump(const Duration(milliseconds: 50));
      tile2.requestFocus();
      await tester.pump(const Duration(milliseconds: 50));

      // Move focus OUT of the row → triggers null-clear (synchronous).
      externalNode.requestFocus();
      await tester.pump(const Duration(milliseconds: 50));

      // Wait past the 400ms debounce so a rogue timer would fire if any.
      await tester.pump(const Duration(milliseconds: 500));

      final nonNullCalls = received.where((x) => x != null).toList();
      final nullCalls = received.where((x) => x == null).toList();

      expect(
        nonNullCalls,
        isEmpty,
        reason: 'No non-null onItemFocus calls expected during fast traversal '
            '(Req 4.2). Got: $nonNullCalls',
      );
      expect(
        nullCalls.length,
        greaterThanOrEqualTo(1),
        reason: 'At least one null-clear is expected when focus leaves the row.',
      );

      externalNode.dispose();
    },
  );

  testWidgets(
    'stable focus on a tile for ≥400 ms dispatches onItemFocus exactly once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final items = [_item(10), _item(20), _item(30)];
      final received = <NowPlayingItem?>[];
      final externalNode = FocusNode();

      await tester.pumpWidget(
        _harness(
          externalNode: externalNode,
          child: CinemaRow(
            title: 'Test',
            items: items,
            onItemTap: (_) {},
            onItemFocus: (item) => received.add(item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile0 = _tileFocusNode(tester, 0);
      tile0.requestFocus();

      // Wait past debounce; Timer(400ms) inside CinemaRow fires.
      await tester.pump(const Duration(milliseconds: 500));

      final nonNullCalls = received.where((x) => x != null).toList();
      expect(
        nonNullCalls.length,
        1,
        reason: 'Exactly one onItemFocus(item) call expected after stable '
            '400ms focus on tile 0 (Req 4.1). Got: $nonNullCalls',
      );
      expect(nonNullCalls.first, items[0]);

      externalNode.dispose();
    },
  );
}
