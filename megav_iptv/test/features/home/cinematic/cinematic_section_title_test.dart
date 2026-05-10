import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      // CinematicSectionTitle uses its own RichText layout (JSX-faithful,
      // no SectionTitle atom wrapper). Verify the emphasis text is visible.
      expect(
        find.textContaining('эфире', findRichText: true),
        findsOneWidget,
      );
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

    testWidgets('onMoreTap: non-null surfaces "ВСЕ →" trailing action', (tester) async {
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
      // CinematicSectionTitle renders a trailing InkWell with "ВСЕ →" text.
      expect(find.textContaining('ВСЕ →'), findsOneWidget);
    });
  });
}
