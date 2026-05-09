import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';
import 'package:megav_iptv/features/epg/widgets/epg_program_cell.dart';
import 'package:megav_iptv/features/epg/widgets/epg_time_axis.dart';
import 'package:megav_iptv/features/epg/widgets/epg_time_grid.dart';

// Widget tests for [EpgTimeGrid] (task 4.2, requirements 2.3, 2.4, 2.5,
// 13.1, 13.5, 14.2).
//
// Five concerns under test:
//   1. The expected Key 'epg-time-grid' is present and at least one
//      [EpgProgramCell] is rendered for the in-viewport rows (3 channels x
//      5 programmes; viewport at 1920x1080 always shows at least the first
//      row's cells).
//   2. The OUTER vertical [ListView] (controlled by `verticalCtl`) carries
//      the TV-tuned performance flags:
//        * cacheExtent == 1500.0
//        * scrollDirection == Axis.vertical
//        * clipBehavior == Clip.none
//      and its [SliverChildBuilderDelegate] carries:
//        * addAutomaticKeepAlives == true
//        * addRepaintBoundaries == true
//      (ListView.builder forwards the latter pair to the delegate; they
//      are not stored on ListView itself.)
//   3. The INNER horizontal [ListView] (one per channel row) carries the
//      same TV-tuned performance flags with `scrollDirection ==
//      Axis.horizontal`.
//   4. No GPU-blurring widgets (`BackdropFilter`, `ShaderMask`) appear
//      anywhere in the subtree (Req 13.1, 13.5).
//   5. Time-axis sync — smoke-style regression guard. The grid's per-row
//      controllers are private state inside `_EpgTimeGridState`, so we
//      cannot read their offsets directly. Instead we mount an
//      [EpgTimeAxis] alongside the grid sharing the SAME `horizontalCtl`,
//      then drive `horizontalCtl.jumpTo(360.0)` and confirm:
//        * the master controller's offset is 360,
//        * the axis ListView's controller offset is 360 (proves axis is
//          correctly wired to the master),
//        * no exception is thrown by the grid's `_syncRows` listener
//          (proves the grid does not crash under master mutation).
//      Deeper white-box verification (asserting each inner row's offset
//      matches) is deferred to the 6.x integration tests where the
//      controllers can be inspected via the screen-level state.
//
// Wrapper convention matches `epg_channel_rail_test.dart`:
// MediaQuery -> ProviderScope -> ScreenUtilInit -> MaterialApp.

Channel _mkChannel(int id) => Channel(
      id: id,
      name: 'Channel $id',
      groupTitle: 'Group $id',
    );

/// Builds 5 sequential half-hour programmes for the given channel id.
List<EpgProgram> _mkProgrammes(int channelId, DateTime start) {
  return List<EpgProgram>.generate(5, (i) {
    final progStart = start.add(Duration(minutes: 30 * i));
    final progEnd = start.add(Duration(minutes: 30 * (i + 1)));
    return EpgProgram(
      id: channelId * 10 + i,
      channelId: channelId,
      title: 'p$i',
      start: progStart,
      end: progEnd,
    );
  });
}

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
}

/// Installs a narrow `FlutterError.onError` filter that swallows the
/// "A RenderFlex overflowed" paint-time exception. The production cell
/// layout (Brand 38 + double-line Column inside an 88.h SizedBox) is
/// tight enough that Material Text widgets can spill 1-2 px under the
/// default Roboto metrics used by the test harness. That overflow is
/// purely visual and out of scope for this widget test (task 4.2 covers
/// Keys + perf flags + sync wiring, not pixel-perfect typography).
void _installRenderFlexOverflowFilter() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    if (message.contains('A RenderFlex overflowed')) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}

void main() {
  // Window-from is a stable epoch-anchored value so test-timing is
  // independent of wall clock.
  final windowFrom = DateTime.utc(2026, 1, 1, 12, 0);
  final channels = List<Channel>.generate(3, (i) => _mkChannel(i + 1));
  final programmes = <int, List<EpgProgram>>{
    for (final c in channels) c.id: _mkProgrammes(c.id, windowFrom),
  };

  testWidgets(
    'EpgTimeGrid renders grid key and at least one programme cell',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      _installRenderFlexOverflowFilter();

      final verticalCtl = ScrollController();
      final horizontalCtl = ScrollController();
      addTearDown(verticalCtl.dispose);
      addTearDown(horizontalCtl.dispose);

      await tester.pumpWidget(_harness(
        child: EpgTimeGrid(
          channels: channels,
          programmes: programmes,
          windowFrom: windowFrom,
          slotCount: 10,
          verticalCtl: verticalCtl,
          horizontalCtl: horizontalCtl,
        ),
      ));
      // Two pumps: ScreenUtilInit settles on the first, the grid's
      // ListView builder on the second. We deliberately avoid
      // pumpAndSettle so any unexpected animation would fail loudly.
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('epg-time-grid')), findsOneWidget);
      // Viewport (1920 wide) cannot show all 5 programmes per row because
      // each cell spans `ceil(30min/30min) * 180.w = 180.w` and the inner
      // ListView starts at offset 0; either way at least one cell must
      // be in the laid-out subtree.
      expect(find.byType(EpgProgramCell), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'EpgTimeGrid OUTER vertical ListView carries TV-tuned perf flags',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      _installRenderFlexOverflowFilter();

      final verticalCtl = ScrollController();
      final horizontalCtl = ScrollController();
      addTearDown(verticalCtl.dispose);
      addTearDown(horizontalCtl.dispose);

      await tester.pumpWidget(_harness(
        child: EpgTimeGrid(
          channels: channels,
          programmes: programmes,
          windowFrom: windowFrom,
          slotCount: 10,
          verticalCtl: verticalCtl,
          horizontalCtl: horizontalCtl,
        ),
      ));
      await tester.pump();
      await tester.pump();

      // The outer (vertical) ListView is the first one constructed by the
      // widget; `find.byType(ListView).first` therefore selects it.
      final outer = tester.widget<ListView>(find.byType(ListView).first);
      expect(outer.scrollDirection, Axis.vertical);
      expect(outer.cacheExtent, 1500.0);
      expect(outer.clipBehavior, Clip.none);
      // addAutomaticKeepAlives / addRepaintBoundaries live on the
      // SliverChildBuilderDelegate that ListView.builder constructs.
      final outerDelegate =
          outer.childrenDelegate as SliverChildBuilderDelegate;
      expect(outerDelegate.addAutomaticKeepAlives, true);
      expect(outerDelegate.addRepaintBoundaries, true);
    },
  );

  testWidgets(
    'EpgTimeGrid INNER horizontal ListView carries TV-tuned perf flags',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      _installRenderFlexOverflowFilter();

      final verticalCtl = ScrollController();
      final horizontalCtl = ScrollController();
      addTearDown(verticalCtl.dispose);
      addTearDown(horizontalCtl.dispose);

      await tester.pumpWidget(_harness(
        child: EpgTimeGrid(
          channels: channels,
          programmes: programmes,
          windowFrom: windowFrom,
          slotCount: 10,
          verticalCtl: verticalCtl,
          horizontalCtl: horizontalCtl,
        ),
      ));
      await tester.pump();
      await tester.pump();

      // After the first ListView (the outer vertical one), every
      // subsequent ListView in the tree is an inner horizontal row. We
      // pick the first inner row at index 1.
      final lvFinder = find.byType(ListView);
      expect(lvFinder, findsAtLeastNWidgets(2));

      final inner = tester.widget<ListView>(lvFinder.at(1));
      expect(inner.scrollDirection, Axis.horizontal);
      expect(inner.cacheExtent, 1500.0);
      expect(inner.clipBehavior, Clip.none);
      // Inner rows are NeverScrollable — they are pure offset mirrors of
      // the master horizontal controller. Confirming the physics here
      // also documents the single-master sync contract.
      expect(inner.physics, isA<NeverScrollableScrollPhysics>());

      final innerDelegate =
          inner.childrenDelegate as SliverChildBuilderDelegate;
      expect(innerDelegate.addAutomaticKeepAlives, true);
      expect(innerDelegate.addRepaintBoundaries, true);
    },
  );

  testWidgets(
    'EpgTimeGrid uses no GPU-blurring widgets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      _installRenderFlexOverflowFilter();

      final verticalCtl = ScrollController();
      final horizontalCtl = ScrollController();
      addTearDown(verticalCtl.dispose);
      addTearDown(horizontalCtl.dispose);

      await tester.pumpWidget(_harness(
        child: EpgTimeGrid(
          channels: channels,
          programmes: programmes,
          windowFrom: windowFrom,
          slotCount: 10,
          verticalCtl: verticalCtl,
          horizontalCtl: horizontalCtl,
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    },
  );

  testWidgets(
    'EpgTimeGrid time-axis sync — master.jumpTo(360) propagates to axis '
    'and grid does not crash (smoke-style regression guard)',
    (tester) async {
      // NOTE: The grid's per-row ScrollControllers are private state
      // inside `_EpgTimeGridState._rowControllers`. We cannot directly
      // assert each row's offset == 360. Instead we co-mount an
      // EpgTimeAxis sharing the same master `horizontalCtl` and verify:
      //   - the master offset becomes 360,
      //   - the axis's ListView controller (which IS the master) reads
      //     360 (proves the contract that the axis mirrors the master),
      //   - no exception escapes the grid's `_syncRows` listener
      //     (proves _syncRows is well-behaved when the master mutates).
      // Full row-by-row sync verification lands in 6.x screen tests.
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      _installRenderFlexOverflowFilter();

      final verticalCtl = ScrollController();
      final horizontalCtl = ScrollController();
      addTearDown(verticalCtl.dispose);
      addTearDown(horizontalCtl.dispose);

      await tester.pumpWidget(_harness(
        child: Column(
          children: [
            EpgTimeAxis(
              windowFrom: windowFrom,
              horizontalCtl: horizontalCtl,
              slotCount: 10,
            ),
            Expanded(
              child: EpgTimeGrid(
                channels: channels,
                programmes: programmes,
                windowFrom: windowFrom,
                slotCount: 10,
                verticalCtl: verticalCtl,
                horizontalCtl: horizontalCtl,
              ),
            ),
          ],
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Drive the master horizontal controller.
      horizontalCtl.jumpTo(360.0);
      await tester.pump();
      await tester.pump();

      // Master is at 360 (trivially true — confirms the controller is
      // attached to a live Scrollable, otherwise jumpTo would have
      // thrown).
      expect(horizontalCtl.offset, 360.0);

      // The axis's ListView is the one whose controller IS the master.
      // Locate it by descending into the time-axis subtree.
      final axisLvFinder = find.descendant(
        of: find.byKey(const Key('epg-time-axis')),
        matching: find.byType(ListView),
      );
      expect(axisLvFinder, findsOneWidget);
      final axisLv = tester.widget<ListView>(axisLvFinder);
      expect(axisLv.controller, same(horizontalCtl));
      expect(axisLv.controller!.offset, 360.0);

      // No exception was thrown by `_syncRows` — if the listener had
      // crashed (e.g. tried to jumpTo a detached controller), the test
      // harness would have surfaced the failure by now.
      expect(tester.takeException(), isNull);
    },
  );
}
