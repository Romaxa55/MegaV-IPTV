import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/player/cinematic/inline_epg_bar.dart';

void main() {
  group('InlineEpgBar', () {
    testWidgets('renders MvTrack and program title with valid range', (tester) async {
      final start = DateTime.now().subtract(const Duration(minutes: 30));
      final end = DateTime.now().add(const Duration(minutes: 30));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InlineEpgBar(
                programTitle: 'Test Program',
                startAt: start, endAt: end,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MvTrack), findsOneWidget);
      expect(find.text('Test Program'), findsOneWidget);
    });

    testWidgets('shows placeholder when programTitle is null', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: InlineEpgBar())),
        ),
      );
      await tester.pump();
      expect(find.text('Программа не загружена'), findsOneWidget);
    });

    testWidgets('progress is 0 when startAt is null', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: InlineEpgBar(programTitle: 'X'))),
        ),
      );
      await tester.pump();
      final track = tester.widget<MvTrack>(find.byType(MvTrack));
      expect(track.progress, 0.0);
    });
  });
}
