import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/perf/perf_safe_widgets.dart';
import 'package:megav_iptv/core/theme/app_palettes.dart';

void main() {
  group('perf_safe_widgets — source-introspection (T-1, T-9)', () {
    test('T-1: source file does not contain BackdropFilter (Req 1.5, 1.6, 10.1)', () {
      final src = File('lib/core/perf/perf_safe_widgets.dart').readAsStringSync();
      // Strip out comment lines (anything starting with /// or //) so the
      // doc-comments that explain "what we replace" don't false-positive.
      final codeOnly = src
          .split('\n')
          .where((line) {
            final trimmed = line.trimLeft();
            return !trimmed.startsWith('///') && !trimmed.startsWith('//');
          })
          .join('\n');
      expect(codeOnly, isNot(contains('BackdropFilter')));
    });

    test('T-9: kSafeShadowBlurMax == 12.0 (Req 7.3)', () {
      expect(kSafeShadowBlurMax, 12.0);
    });
  });

  group('SafePill (T-3)', () {
    testWidgets('T-3: renders Container with non-null tinted color (Req 2.2)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafePill(
              child: Text('LIVE'),
            ),
          ),
        ),
      );
      expect(find.byType(SafePill), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      // Find inner Container with non-null decoration.color (non-empty pill).
      final container = tester.widgetList<Container>(find.byType(Container)).firstWhere(
            (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).color != null,
          );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      // No BackdropFilter ancestors:
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('SafeFocusRing (T-4, T-5)', () {
    testWidgets('T-4: toggles between focused/unfocused decoration (Req 3.3)', (tester) async {
      bool focused = false;
      late StateSetter setter;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (ctx, set) {
              setter = set;
              return Scaffold(
                body: Center(
                  child: SafeFocusRing(
                    isFocused: focused,
                    child: const SizedBox(width: 100, height: 100),
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Initially unfocused — find AnimatedContainer, decoration.boxShadow empty.
      AnimatedContainer ac = tester.widget(find.byType(AnimatedContainer));
      var deco = ac.decoration as BoxDecoration;
      expect(deco.boxShadow, isEmpty);

      // Toggle focus.
      setter(() => focused = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      ac = tester.widget(find.byType(AnimatedContainer));
      deco = ac.decoration as BoxDecoration;
      expect(deco.boxShadow, isNotEmpty);
      expect(deco.boxShadow!.length, 2);
    });

    testWidgets('T-5: all BoxShadow blurRadius == 0 (Req 3.7)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SafeFocusRing(
                isFocused: true,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final ac = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final deco = ac.decoration as BoxDecoration;
      expect(deco.boxShadow, isNotNull);
      for (final s in deco.boxShadow!) {
        expect(s.blurRadius, 0.0, reason: 'BoxShadow.blurRadius must be 0 (Req 3.7)');
      }
    });
  });

  group('SafeFilmGrain (T-6, T-7)', () {
    testWidgets('T-6: composites without explicit BlendMode override (Req 4.3)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeFilmGrain(
              opacity: 0.08,
              child: ColoredBox(color: Color(0xFF000000)),
            ),
          ),
        ),
      );
      // Spot-check: there's an Opacity wrapper with the configured opacity.
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.08);
      // No BackdropFilter:
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('T-7: opacity > 0.20 clamps to 0.20', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeFilmGrain(
              opacity: 0.50,
              child: ColoredBox(color: Color(0xFF000000)),
            ),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.20);
    });
  });

  group('SafeBackdrop (T-2)', () {
    testWidgets('T-2: null imageProvider renders fallbackBackground without crash (Req 1.4)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeBackdrop(
              imageProvider: null,
              fallbackBackground: Color(0xFF112233),
            ),
          ),
        ),
      );
      await tester.pump();
      // ColoredBox with the fallback color is in the SafeBackdrop subtree.
      final cb = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(SafeBackdrop),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(cb.color, const Color(0xFF112233));
      // No exception was thrown.
      expect(tester.takeException(), isNull);
    });
  });

  group('combinedHeroGradient (T-8)', () {
    test('T-8: returns RadialGradient with 4 stops; different palettes produce different first-stop color', () {
      final noir = combinedHeroGradient(AppPaletteName.noirCobalt.resolve());
      final crimson = combinedHeroGradient(AppPaletteName.crimsonReel.resolve());

      expect(noir, isA<RadialGradient>());
      expect(noir.stops, hasLength(4));
      expect(noir.colors, hasLength(4));

      // First color is palette.background — must differ across palettes.
      expect(noir.colors.first, isNot(equals(crimson.colors.first)));
    });
  });
}
