import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/home/editorial/editorial_genre_tabs_bar.dart';

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

const _genres = ['Все', 'Кино', 'Сериалы', 'Спорт', 'Детям'];

void main() {
  testWidgets(
    'EditorialGenreTabsBar exposes root key + GenreTabs atom',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditorialGenreTabsBar(
            tabs: _genres,
            activeIndex: 2,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('editorial-genre-tabs')), findsOneWidget);
      expect(find.byType(GenreTabs), findsOneWidget);
    },
  );

  testWidgets(
    'EditorialGenreTabsBar does not introduce a ShaderMask (Req 8.4)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditorialGenreTabsBar(
            tabs: _genres,
            activeIndex: 2,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Req 8.4 / 9.1 enforcement — perf gate at the widget-tree level.
      expect(find.byType(ShaderMask), findsNothing);
    },
  );

  testWidgets(
    'EditorialGenreTabsBar renders left + right edge-fade DecoratedBoxes',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          EditorialGenreTabsBar(
            tabs: _genres,
            activeIndex: 2,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Two edge-fade overlays (left + right). The widget tree may carry
      // additional DecoratedBoxes from the underlying GenreTabs atom, so
      // we only assert the lower bound.
      expect(find.byType(DecoratedBox), findsAtLeastNWidgets(2));
    },
  );
}
