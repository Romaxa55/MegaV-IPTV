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

void main() {
  testWidgets(
    'focusing tile 5 scrolls the row to the leading-edge offset (Req 2.1, 2.2)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 10 items so tile 5 is well past the visible window.
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

      // Pick the row's horizontal Scrollable from the inner ListView.
      final scrollableFinder = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      );
      expect(scrollableFinder, findsOneWidget,
          reason: 'CinemaRow must contain exactly one horizontal Scrollable');
      final scrollableState = tester.state<ScrollableState>(scrollableFinder);

      // Initial offset before any focus → 0.
      expect(scrollableState.position.pixels, 0.0);

      // Measure the actual rendered tile width by querying the RenderBox of
      // tile 0. The leading-edge formula is `index * (cardW + gap)` where
      // both values are screenutil-scaled. Because flutter_screenutil reads
      // the platform View size (which differs from the test surface size in
      // some Flutter versions), we read the post-layout cardW directly from
      // the rendered tile instead of recomputing analytically. The math
      // invariant of the formula (5 * (cardW + gap)) is what we actually
      // care about.
      final tile0Finder = find.byWidgetPredicate(
        (w) =>
            w is Focus &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.endsWith('_0'),
      );
      final tile0Box = tester.renderObject<RenderBox>(tile0Finder.first);
      final tile0Width = tile0Box.size.width; // includes the trailing gap padding
      // tile0 in `cinema_row.dart` is `Padding(right: gap, child: ...)`. So
      // tile0Box.size.width == cardW + gap (except for the last index where
      // padding is 0).

      // ListView lazily materializes tiles. To bring tile 5 into the build
      // tree we walk focus forward through the visible tiles, settling
      // animations between hops so the next tile is materialised before we
      // resolve its FocusNode.
      for (var i = 0; i <= 5; i++) {
        final node = _tileFocusNode(tester, i);
        node.requestFocus();
        await tester.pump(); // process focus + setState
        await tester.pump(); // postFrame callback → animateTo
        await tester.pump(GridTokens.scrollAnimation + const Duration(milliseconds: 50));
      }

      // Expected offset is `5 * (cardW + gap)`. Since `tile0Width = cardW + gap`,
      // expected = 5 * tile0Width.
      final expected = 5 * tile0Width;
      final actual = scrollableState.position.pixels;

      // Allow ±2 px tolerance for floating-point + clamping.
      expect(
        actual,
        closeTo(expected, 2.0),
        reason: 'After focusing tile 5, the leading-edge scroll offset should be '
            '5 * (cardW + gap) = $expected px (±2). Got $actual. '
            '(tile0Width = $tile0Width)',
      );

      externalNode.dispose();
    },
  );
}
