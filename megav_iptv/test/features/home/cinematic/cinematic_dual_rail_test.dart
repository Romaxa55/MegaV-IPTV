import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_dual_rail.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_rail.dart';

void main() {
  final items = List<CinematicRailItem>.generate(
    3,
    (i) => CinematicRailItem(id: 'i$i', title: 'Item $i', imageProvider: null),
  );

  group('CinematicDualRail', () {
    testWidgets('landscape ctor renders landscape key', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicDualRail.landscape(items: items),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('cinematic-dual-rail-landscape')), findsOneWidget);
    });

    testWidgets('portrait ctor renders portrait key', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicDualRail.portrait(items: items),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('cinematic-dual-rail-portrait')), findsOneWidget);
    });

    testWidgets('ListView has TV-tuned perf flags', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicDualRail.landscape(items: items),
            ),
          ),
        ),
      );
      await tester.pump();
      final lv = tester.widget<ListView>(find.byType(ListView));
      expect(lv.cacheExtent, 1500.0);
      expect(lv.clipBehavior, Clip.none);
      // addAutomaticKeepAlives / addRepaintBoundaries live on the
      // SliverChildBuilderDelegate (final bool fields), not on ListView.
      final delegate = lv.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.addAutomaticKeepAlives, true);
      expect(delegate.addRepaintBoundaries, true);
    });

    testWidgets('no BackdropFilter/ShaderMask in tree', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicDualRail.landscape(items: items),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    });
  });
}
