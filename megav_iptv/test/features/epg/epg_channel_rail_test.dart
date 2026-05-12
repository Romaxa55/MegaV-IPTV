import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/channel.dart';
import 'package:megav_iptv/features/epg/widgets/epg_channel_rail.dart';

// Widget tests for [EpgChannelRail] (task 3.2, requirements 13.1, 13.5, 14.2).
//
// Three concerns under test:
//   1. The expected Keys are present in the rendered tree:
//        * 'epg-channel-rail' on the SizedBox wrapper.
//        * 'epg-channel-cell-<id>' on each cell (we assert id=1 is in the
//          first viewport, since the rail starts scrolled at the top).
//   2. The ListView exposes the TV-tuned performance flags:
//        * cacheExtent == 1500.0
//        * clipBehavior == Clip.none
//      And the SliverChildBuilderDelegate carries:
//        * addAutomaticKeepAlives == true
//        * addRepaintBoundaries == true
//      (Flutter forwards the latter two from ListView.builder onto the
//       delegate; they are not stored on ListView itself.)
//   3. No GPU-blurring widgets are present anywhere in the subtree:
//        find.byType(BackdropFilter) and find.byType(ShaderMask) are empty.
//      This guards the EPG perf contract (Req 13.1, 13.5).
//
// Wrapper convention matches `epg_screen_smoke_test.dart` and the cinematic
// home tests: MediaQuery → ProviderScope → ScreenUtilInit → MaterialApp,
// because the rail uses ScreenUtil's `.w` / `.h` extensions.

Channel _mkChannel(int id) => Channel(
      id: id,
      name: 'Channel $id',
      groupTitle: 'Group $id',
    );

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

void main() {
  final channels = List<Channel>.generate(5, (i) => _mkChannel(i + 1));

  testWidgets(
    'EpgChannelRail renders rail key and first cell key',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // GH issue #15: cell ROW_H bumped 88→92 → overflow gone. No
      // need to suppress RenderFlex assertions anymore.

      final verticalCtl = ScrollController();
      addTearDown(verticalCtl.dispose);

      await tester.pumpWidget(_harness(
        child: EpgChannelRail(
          channels: channels,
          verticalCtl: verticalCtl,
          focusedChannelIndex: 0,
          onFocusChanged: (_) {},
        ),
      ));
      // Two pumps: ScreenUtilInit settles on the first, ConsumerState body
      // on the second. We deliberately avoid pumpAndSettle so any
      // unexpected animation would fail loudly.
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('epg-channel-rail')), findsOneWidget);
      expect(
        find.byKey(const Key('epg-channel-cell-1')),
        findsAtLeastNWidgets(1),
      );
    },
  );

  testWidgets(
    'EpgChannelRail ListView carries TV-tuned perf flags',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // GH issue #15: cell ROW_H bumped 88→92 → overflow gone. No
      // need to suppress RenderFlex assertions anymore.

      final verticalCtl = ScrollController();
      addTearDown(verticalCtl.dispose);

      await tester.pumpWidget(_harness(
        child: EpgChannelRail(
          channels: channels,
          verticalCtl: verticalCtl,
          focusedChannelIndex: 0,
          onFocusChanged: (_) {},
        ),
      ));
      await tester.pump();
      await tester.pump();

      final lv = tester.widget<ListView>(find.byType(ListView));
      expect(lv.cacheExtent, 1500.0);
      expect(lv.clipBehavior, Clip.none);
      // addAutomaticKeepAlives / addRepaintBoundaries are stored on the
      // SliverChildBuilderDelegate that ListView.builder constructs, not
      // on the ListView itself.
      final delegate = lv.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.addAutomaticKeepAlives, true);
      expect(delegate.addRepaintBoundaries, true);
    },
  );

  testWidgets(
    'EpgChannelRail uses no GPU-blurring widgets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // GH issue #15: cell ROW_H bumped 88→92 → overflow gone. No
      // need to suppress RenderFlex assertions anymore.

      final verticalCtl = ScrollController();
      addTearDown(verticalCtl.dispose);

      await tester.pumpWidget(_harness(
        child: EpgChannelRail(
          channels: channels,
          verticalCtl: verticalCtl,
          focusedChannelIndex: 0,
          onFocusChanged: (_) {},
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    },
  );
}
