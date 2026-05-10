import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/editorial/editorial_section_title.dart';

Widget _wrap(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, _) {
          return MaterialApp(
            home: Scaffold(body: child),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets(
    'EditorialSectionTitle delegates to SectionTitle atom and renders italic emphasis',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditorialSectionTitle(
            label: 'Кино',
            emphasis: 'без расписания',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SectionTitle), findsOneWidget);
      // Emphasis fragment renders as a sibling Text widget inside SectionTitle.
      expect(
        find.textContaining('без расписания', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'EditorialSectionTitle forwards count to SectionTitle ghost chip',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditorialSectionTitle(
            label: 'Кино',
            emphasis: 'без расписания',
            count: 30,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('30'), findsOneWidget);
    },
  );

  testWidgets(
    'EditorialSectionTitle exposes a focusable trailing action when onMoreTap is set',
    (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          EditorialSectionTitle(
            label: 'Кино',
            emphasis: 'без расписания',
            onMoreTap: () => tapped++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      // The atom renders an MvButton.ghost when onMore is non-null. We
      // verify the trailing action exists and that tapping it dispatches
      // the callback.
      final moreButton = find.text('more →');
      expect(moreButton, findsOneWidget);
      await tester.tap(moreButton);
      await tester.pump();
      expect(tapped, 1);
    },
  );
}
