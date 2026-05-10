import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/editorial/editorial_film_reel_strip.dart';

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
    'EditorialFilmReelStrip renders key + MvStrip + eyebrow + counter',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EditorialFilmReelStrip(
            channelCount: 124,
            activeIndex: 4,
            frameCount: 18,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editorial-film-reel-strip')), findsOneWidget);
      expect(find.byType(MvStrip), findsOneWidget);
      expect(find.text('КАНАЛЫ ↓'), findsOneWidget);
      expect(find.text('05 / 124'), findsOneWidget);
    },
  );

  testWidgets(
    'EditorialFilmReelStrip does not introduce BackdropFilter',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EditorialFilmReelStrip(
            channelCount: 124,
            activeIndex: 4,
            frameCount: 18,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Req 9.1 enforcement — perf gate at the widget-tree level.
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );
}
