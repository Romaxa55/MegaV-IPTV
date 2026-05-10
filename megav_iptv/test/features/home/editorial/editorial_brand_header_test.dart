import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/editorial/editorial_brand_header.dart';

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
    'EditorialBrandHeader exposes root key + Brand + StatusBar atoms',
    (tester) async {
      await tester.pumpWidget(_wrap(const EditorialBrandHeader()));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editorial-brand-header')), findsOneWidget);
      expect(find.byType(Brand), findsOneWidget);
      expect(find.byType(StatusBar), findsOneWidget);
    },
  );

  testWidgets(
    'EditorialBrandHeader applies scale via Transform',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const EditorialBrandHeader(scale: 1.6)),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Transform.scale produces a Transform widget wrapping the Brand atom.
      // Scope to descendants of the keyed root so transforms introduced by
      // the test shell (MaterialApp, navigators) are excluded.
      expect(
        find.descendant(
          of: find.byKey(const Key('editorial-brand-header')),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );
    },
  );
}
