import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/cinematic/cinematic_section_title.dart';

void main() {
  group('CinematicSectionTitle', () {
    testWidgets('renders SectionTitle atom + emphasis text', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicSectionTitle(
                label: 'Сейчас в',
                emphasis: 'эфире',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SectionTitle), findsOneWidget);
      expect(find.text('эфире'), findsOneWidget);
    });

    testWidgets('count: 12 surfaces in tree', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicSectionTitle(
                label: 'Сейчас в',
                emphasis: 'эфире',
                count: 12,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('12'), findsAtLeastNWidgets(1));
    });

    testWidgets('onMoreTap: non-null surfaces "more →" trailing action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CinematicSectionTitle(
                label: 'X',
                onMoreTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // SectionTitle internally renders MvButton.ghost when onMore != null.
      expect(find.byType(MvButton), findsOneWidget);
    });
  });
}
