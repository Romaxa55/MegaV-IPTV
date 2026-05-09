import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_genre_tabs_bar.dart';

void main() {
  group('CinematicGenreTabsBar', () {
    testWidgets('renders root key + atom GenreTabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicGenreTabsBar(
                labels: const ['Все', 'Кино', 'Сериалы', 'Спорт', 'Новости'],
                activeIndex: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('cinematic-genre-tabs')), findsOneWidget);
      expect(find.byType(GenreTabs), findsOneWidget);
    });

    testWidgets('does not use ShaderMask widget', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicGenreTabsBar(
                labels: const ['A', 'B', 'C'],
                activeIndex: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('renders edge-fade DecoratedBox overlays', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicGenreTabsBar(
                labels: const ['A', 'B', 'C'],
                activeIndex: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // At least 2 DecoratedBox widgets exist (left + right fade overlays)
      expect(find.byType(DecoratedBox), findsAtLeastNWidgets(2));
    });
  });
}
