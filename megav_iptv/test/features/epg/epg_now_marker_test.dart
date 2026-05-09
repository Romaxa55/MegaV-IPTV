import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/perf/perf_safe_widgets.dart';
import 'package:megav_iptv/features/epg/widgets/epg_now_marker.dart';

// Widget tests for [EpgNowMarker] (task 4.4, requirements 6.2, 6.3, 13.1,
// 13.2, 13.4, 14.2).
//
// Four concerns under test:
//   1. Horizontal placement of the marker corresponds to nowOffsetX with the
//      provided slot width and time delta. We assert via
//      `tester.getTopLeft(...)` against the expected x coordinate.
//      NOTE: the canonical task description uses "windowFrom = now - 30min"
//      paired with "marker positioned at offset corresponding to ~slotW/2"
//      which is internally inconsistent — `(30/30)*180 = 180`, not 90. We
//      align to the *assertion* (~slotW/2 = ~90 px) and pick `windowFrom =
//      now - 15min` so that `nowOffsetX = (15/30) * 180 = 90`. This is a
//      conscious deviation from the literal `30min` figure in step 1; the
//      observable contract under test (offset proportional to elapsed
//      time, scaled by .w) is preserved (Req 6.2).
//   2. The marker subtree contains at least one `RepaintBoundary` ancestor
//      (the private `_NowMarkerLine` is wrapped in one) — Req 6.4 / 13.4.
//   3. No GPU-blurring widgets (`BackdropFilter` / `ShaderMask`) anywhere
//      in the marker tree — Req 13.1.
//   4. Every `BoxShadow` reachable from the marker subtree has
//      `blurRadius <= kSafeShadowBlurMax` — Req 13.2 (TV-Mali safety
//      contract). We walk `tester.allWidgets` and inspect every widget
//      that exposes a `BoxDecoration` with `boxShadow`.
//
// Wrapper convention matches `epg_program_cell_test.dart`:
//   MediaQuery -> ProviderScope -> ScreenUtilInit(1920x1080) ->
//   MaterialApp -> Scaffold -> Stack (REQUIRED — `EpgNowMarker.build`
//   returns a `Positioned`, which must be a direct child of a `Stack`).
//
// Pump policy: `pumpAndSettle` is deliberately avoided. The private
// `_NowMarkerLine` runs a `Timer.periodic(30s)` that would keep the
// scheduler busy forever. Two manual pumps are sufficient — Timer
// callbacks do not fire because no virtual time elapses, and the timer
// is cancelled in `dispose()` when the binding tears down the tree.

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Stack(
              children: [child],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Walks every widget currently mounted under [tester] and collects the
/// `boxShadow` lists from any widget that exposes a `BoxDecoration`. We
/// look at three concrete widget types that production code uses to host
/// shadows: `DecoratedBox`, `Container`, `AnimatedContainer`.
List<BoxShadow> _collectBoxShadows(WidgetTester tester) {
  final shadows = <BoxShadow>[];

  void collectFromDecoration(Decoration? decoration) {
    if (decoration is BoxDecoration) {
      final list = decoration.boxShadow;
      if (list != null) shadows.addAll(list);
    }
  }

  for (final w in tester.allWidgets) {
    if (w is DecoratedBox) {
      collectFromDecoration(w.decoration);
    } else if (w is Container) {
      collectFromDecoration(w.decoration);
    } else if (w is AnimatedContainer) {
      collectFromDecoration(w.decoration);
    }
  }
  return shadows;
}

void main() {
  testWidgets(
    'EpgNowMarker positions key at nowOffsetX(now, windowFrom, slotW).w',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // windowFrom = now - 15 min: the elapsed half-slot drives the
      // production formula `(minutes / 30) * slotW = (15/30)*180 = 90`,
      // which matches the "~slotW/2" assertion in the task spec.
      final windowFrom = DateTime.now().subtract(const Duration(minutes: 15));
      const slotW = 180.0;
      const gridHeight = 600.0;

      await tester.pumpWidget(_harness(
        child: EpgNowMarker(
          windowFrom: windowFrom,
          slotW: slotW,
          gridHeight: gridHeight,
          accent: Colors.cyan,
        ),
      ));
      // Two pumps: ScreenUtilInit settles on the first, the marker body
      // on the second. We deliberately avoid pumpAndSettle — the inner
      // _NowMarkerLine runs Timer.periodic(30s) which would loop forever.
      await tester.pump();
      await tester.pump();

      // Production formula: `Positioned.left = nowOffsetX(...) .w`. The
      // raw nowOffsetX value here is `(15/30)*180 = 90`. ScreenUtil's `.w`
      // multiplies by `MediaQuery.size.width / designSize.width`. In the
      // flutter_test binding the implicit-view size is 800x600 regardless
      // of `setSurfaceSize` — ScreenUtilInit reads its value during build
      // before our outer MediaQuery override fully propagates — so the
      // observed scale factor is `800 / 1920 ≈ 0.4167`, yielding the
      // expected dx ≈ 37.5 px. We assert against that scaled value to
      // pin the contract: position is proportional to elapsed time and
      // scales by `.w` (Req 6.2).
      final markerFinder = find.byKey(const Key('epg-now-marker'));
      expect(markerFinder, findsOneWidget);

      // Compute the same scale ScreenUtil applies, by reading from a
      // context inside the harness rather than guessing.
      final scaleW = 1.0.w;
      final expectedDx = 90.0 * scaleW;

      final dx = tester.getTopLeft(markerFinder).dx;
      // Tolerance ±15 * scaleW px: covers second-level drift between the
      // call to `DateTime.now()` inside `build()` and our reference
      // `windowFrom`. At worst-case 1 s skew the offset moves
      // `(1/30)*180.w = 6.w` px.
      expect(
        dx,
        closeTo(expectedDx, 15.0 * scaleW),
        reason:
            'Expected marker at (15/30)*180.w = ${expectedDx.toStringAsFixed(2)} '
            'px (±${(15.0 * scaleW).toStringAsFixed(2)} tolerance, '
            'scaleW=$scaleW) — observed dx=$dx.',
      );
    },
  );

  testWidgets(
    'EpgNowMarker subtree contains a RepaintBoundary',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final windowFrom = DateTime.now().subtract(const Duration(minutes: 15));

      await tester.pumpWidget(_harness(
        child: EpgNowMarker(
          windowFrom: windowFrom,
          slotW: 180,
          gridHeight: 600,
          accent: Colors.cyan,
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Req 6.4 / 13.4: the half-minute setState in `_NowMarkerLine`
      // must repaint in isolation. The private widget wraps its body in
      // a RepaintBoundary; we assert it exists as a descendant of the
      // public `epg-now-marker` key (the private type itself is not
      // accessible from outside the library).
      final descendant = find.descendant(
        of: find.byKey(const Key('epg-now-marker')),
        matching: find.byType(RepaintBoundary),
      );
      expect(descendant, findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'EpgNowMarker uses no GPU-blurring widgets',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final windowFrom = DateTime.now().subtract(const Duration(minutes: 15));

      await tester.pumpWidget(_harness(
        child: EpgNowMarker(
          windowFrom: windowFrom,
          slotW: 180,
          gridHeight: 600,
          accent: Colors.cyan,
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Req 13.1: no BackdropFilter / ShaderMask in the EPG screen tree.
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
    },
  );

  testWidgets(
    'EpgNowMarker BoxShadow blurRadius never exceeds kSafeShadowBlurMax',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final windowFrom = DateTime.now().subtract(const Duration(minutes: 15));

      await tester.pumpWidget(_harness(
        child: EpgNowMarker(
          windowFrom: windowFrom,
          slotW: 180,
          gridHeight: 600,
          accent: Colors.cyan,
        ),
      ));
      await tester.pump();
      await tester.pump();

      // Req 13.2: every reachable BoxShadow.blurRadius must respect the
      // TV-Mali safe cap. We collect shadows from every DecoratedBox /
      // Container / AnimatedContainer in the tree (these are the only
      // shadow hosts the production widget uses).
      final shadows = _collectBoxShadows(tester);
      expect(
        shadows,
        isNotEmpty,
        reason: 'Expected at least one BoxShadow (line glow + NOW pill glow).',
      );
      for (final s in shadows) {
        expect(
          s.blurRadius,
          lessThanOrEqualTo(kSafeShadowBlurMax),
          reason:
              'BoxShadow.blurRadius=${s.blurRadius} exceeds kSafeShadowBlurMax='
              '$kSafeShadowBlurMax (Req 13.2).',
        );
      }
    },
  );
}
