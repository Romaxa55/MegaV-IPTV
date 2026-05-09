import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_live_strip.dart';

void main() {
  group('CinematicLiveStrip', () {
    testWidgets('renders root key + Chip(live) + MMLogo + MvTrack', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicLiveStrip(
                currentTitle: 'Now Playing',
                nextLabel: 'Next at 21:00',
                progress: 0.42,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('cinematic-live-strip')), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
      expect(find.byType(MMLogo), findsOneWidget);
      expect(find.byType(MvTrack), findsOneWidget);
    });

    testWidgets('progress consumer wrapped in RepaintBoundary', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicLiveStrip(progress: 0.3),
            ),
          ),
        ),
      );
      await tester.pump();

      // MvTrack must have a RepaintBoundary ancestor for stream-consumer isolation
      expect(
        find.ancestor(
          of: find.byType(MvTrack),
          matching: find.byType(RepaintBoundary),
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
