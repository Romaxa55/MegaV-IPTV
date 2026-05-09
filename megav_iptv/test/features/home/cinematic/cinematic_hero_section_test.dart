import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/perf/perf_safe_widgets.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_hero_section.dart';

void main() {
  group('CinematicHeroSection', () {
    testWidgets('renders root key + SafeBackdrop + SafeFilmGrain', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicHeroSection(
                title: 'Test Title',
                channelName: 'Test Channel',
                programLabel: 'Now: Test Program',
                onWatch: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('cinematic-hero')), findsOneWidget);
      expect(find.byType(SafeBackdrop), findsAtLeastNWidgets(1));
      expect(find.byType(SafeFilmGrain), findsAtLeastNWidgets(1));
    });

    testWidgets('does not use forbidden BackdropFilter widget', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicHeroSection(
                title: 'X',
                onWatch: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('title text uses italic font style', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicHeroSection(
                title: 'Italic Title',
                onWatch: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final titleWidget = tester.widget<Text>(find.text('Italic Title'));
      expect(titleWidget.style?.fontStyle, FontStyle.italic);
    });
  });
}
