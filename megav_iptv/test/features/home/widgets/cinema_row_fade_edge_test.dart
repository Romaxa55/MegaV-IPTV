import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/playlist/models/now_playing.dart';
import 'package:megav_iptv/core/theme/app_colors.dart';
import 'package:megav_iptv/features/home/widgets/cinema_row.dart';

NowPlayingItem _item(int id) => NowPlayingItem(
      channelId: id,
      channelName: 'Channel $id',
      groupTitle: 'Movies',
      logoUrl: null,
      thumbnailUrl: null,
      program: null,
    );

/// Wraps the [child] in a runtime-realistic harness so screenutil resolves
/// `.w/.h/.sp` to identity scale (designSize == runtime size).
///
/// IMPORTANT: must be paired with `tester.binding.setSurfaceSize(Size(1920, 1080))`
/// so the actual render surface matches the MediaQuery override.
Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ScreenUtilInit(
      designSize: const Size(1920, 1080),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'CinemaRow renders right-edge fade overlay via DecoratedBox+LinearGradient (Req 1.1, 1.3)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final items = List.generate(6, (i) => _item(100 + i));

      await tester.pumpWidget(
        _harness(
          child: CinemaRow(
            title: 'Test',
            items: items,
            onItemTap: (_) {},
            onItemFocus: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test 1: NO ShaderMask is used. The previous shader-based fade was
      // replaced with a cheap DecoratedBox overlay because ShaderMask + dstOut
      // forced GL shader compilation (~260 ms jank on first scroll) and a
      // saveLayer over the full row width (~26 ms/frame).
      expect(
        find.byType(ShaderMask),
        findsNothing,
        reason: 'ShaderMask must not be used for fade-edge — it was replaced '
            'with a cheap DecoratedBox+LinearGradient overlay for perf '
            '(Req 1.1, perf-regression fix).',
      );

      // Test 2: A DecoratedBox with horizontal LinearGradient ending in
      // AppColors.background sits next to the ListView in the row's Stack.
      // This is the new fade-edge implementation.
      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      DecoratedBox? fadeOverlay;
      for (final db in decoratedBoxes) {
        final dec = db.decoration;
        if (dec is BoxDecoration) {
          final g = dec.gradient;
          if (g is LinearGradient &&
              g.colors.length == 2 &&
              g.colors.last == AppColors.background &&
              g.begin == Alignment.centerLeft &&
              g.end == Alignment.centerRight) {
            fadeOverlay = db;
            break;
          }
        }
      }
      expect(
        fadeOverlay,
        isNotNull,
        reason: 'A DecoratedBox with a horizontal LinearGradient '
            '(transparent → AppColors.background) must exist as the fade-edge '
            'overlay (Req 1.1).',
      );

      // Test 3: The overlay's gradient starts transparent so the LEFT side of
      // the overlay strip blends invisibly into the visible tiles below it.
      // (Req 1.3: left edge of the row does NOT fade — only the right strip is
      // affected, and even the strip starts transparent.)
      final dec = (fadeOverlay!.decoration as BoxDecoration).gradient
          as LinearGradient;
      final firstColor = dec.colors.first;
      expect(
        firstColor.alpha,
        0,
        reason: 'Fade-edge gradient must start at transparent so the strip '
            'does not visually clip the visible tiles to its left (Req 1.3).',
      );

      // Test 4: The overlay is wrapped in IgnorePointer so it never absorbs
      // taps that should reach the underlying tiles.
      final ignorePointer = tester.firstWidget<IgnorePointer>(
        find.ancestor(
          of: find.byWidget(fadeOverlay),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(
        ignorePointer.ignoring,
        isTrue,
        reason: 'Fade-edge overlay must be wrapped in IgnorePointer so it does '
            'not block focus / tap on the tiles beneath.',
      );
    },
  );
}
