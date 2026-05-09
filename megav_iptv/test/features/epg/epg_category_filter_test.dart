import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';
import 'package:megav_iptv/features/epg/widgets/epg_category_filter.dart';

// Widget tests for [EpgCategoryFilter] (task 5.5, requirements 8.1, 8.3,
// 8.4, 13.1).
//
// Three concerns under test:
//   1. The filter renders the expected Key on its `SizedBox` wrapper and
//      composes the unmodified `GenreTabs` atom (Req 8.4):
//        * `Key('epg-category-filter')` findsOneWidget.
//        * `find.byType(GenreTabs)` findsOneWidget.
//   2. Edge-fade overlays are realised via `DecoratedBox(LinearGradient)`
//      layers — at least two are present (one on the left, one on the
//      right, Req 8.3).
//   3. No `ShaderMask` is used — gradient overlays must avoid the
//      saveLayer cost the spec explicitly forbids (Req 8.3, 13.1).
//
// Wrapper convention matches the rest of the EPG widget-test suite:
// MediaQuery → ProviderScope → ScreenUtilInit → MaterialApp, because the
// filter uses ScreenUtil's `.w` / `.h` extensions.

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  const categories = <String>['Кино', 'Спорт', 'Новости'];

  testWidgets(
    'EpgCategoryFilter renders root key and embeds GenreTabs atom',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(
        child: EpgCategoryFilter(
          categories: categories,
          // null → «Все» (no client-side filter applied, Req 8.2).
          selectedCategory: null,
          onCategorySelected: (_) {},
        ),
      ));
      // Two pumps: ScreenUtilInit settles on the first, the filter body
      // on the second. No pumpAndSettle — guards against accidentally
      // introduced infinite animations.
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('epg-category-filter')), findsOneWidget);
      // Req 8.4: the GenreTabs atom is composed in unmodified — exactly
      // one instance under the filter wrapper.
      expect(find.byType(GenreTabs), findsOneWidget);
    },
  );

  testWidgets(
    'EpgCategoryFilter renders edge-fade DecoratedBox overlays',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(
        child: EpgCategoryFilter(
          categories: categories,
          selectedCategory: null,
          onCategorySelected: (_) {},
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Req 8.3: edge fades are pure DecoratedBox(LinearGradient) layers
      // (no ShaderMask). The filter declares two — left and right — so
      // we assert at least two DecoratedBox widgets exist in the tree.
      // Note: GenreTabs itself may also draw DecoratedBoxes internally,
      // hence `findsAtLeastNWidgets(2)` rather than equality.
      expect(find.byType(DecoratedBox), findsAtLeastNWidgets(2));
    },
  );

  testWidgets(
    'EpgCategoryFilter does not use ShaderMask',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(
        child: EpgCategoryFilter(
          categories: categories,
          selectedCategory: null,
          onCategorySelected: (_) {},
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Req 8.3 / 13.1: ShaderMask is forbidden — gradient overlays
      // avoid the per-frame saveLayer cost ShaderMask would impose.
      expect(find.byType(ShaderMask), findsNothing);
    },
  );
}
