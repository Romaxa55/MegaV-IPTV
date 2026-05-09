import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_home_screen.dart';

void main() {
  testWidgets(
    'CinematicHomeScreen mounts without exception and exposes all 6 component keys',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CinematicHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('cinematic-home-root')), findsOneWidget);
      expect(find.byKey(const Key('cinematic-genre-tabs')), findsOneWidget);
      expect(find.byKey(const Key('cinematic-hero')), findsOneWidget);
      // Below-the-fold items may be offstage in the default test viewport
      // (~600x800). Use skipOffstage: false to assert structural mount
      // without relying on scroll position.
      expect(find.byKey(const Key('cinematic-dual-rail-landscape'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('cinematic-live-strip'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('cinematic-dual-rail-portrait'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('cinematic-remote-hint'), skipOffstage: false), findsOneWidget);
    },
  );
}
