import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/theme/app_palette.dart';
import 'package:megav_iptv/core/theme/app_palettes.dart';

void main() {
  group('AppPaletteName enum', () {
    test('has exactly 6 values', () {
      expect(AppPaletteName.values.length, 6);
    });

    test('contains all expected names in expected order', () {
      expect(AppPaletteName.values, [
        AppPaletteName.plum,
        AppPaletteName.ivory,
        AppPaletteName.noirCobalt,
        AppPaletteName.pitch,
        AppPaletteName.crimsonReel,
        AppPaletteName.modern,
      ]);
    });

    test('every name resolves to a non-null AppPalette with all 17 tokens populated', () {
      for (final name in AppPaletteName.values) {
        final p = name.resolve();
        // 17 fields — verify each is a Color
        expect(p.background, isA<Color>());
        expect(p.backgroundWarm, isA<Color>());
        expect(p.surface1, isA<Color>());
        expect(p.surface2, isA<Color>());
        expect(p.line, isA<Color>());
        expect(p.lineStrong, isA<Color>());
        expect(p.text, isA<Color>());
        expect(p.textDim, isA<Color>());
        expect(p.textMute, isA<Color>());
        expect(p.accent, isA<Color>());
        expect(p.accentGlow, isA<Color>());
        expect(p.accentSoft, isA<Color>());
        expect(p.gold, isA<Color>());
        expect(p.goldSoft, isA<Color>());
        expect(p.live, isA<Color>());
        expect(p.liveSoft, isA<Color>());
        expect(p.good, isA<Color>());
      }
    });

    test('palettes are mostly unique (>= 5 distinct instances)', () {
      // Note: CSS `.theme-plum` happens to coincide with noirCobalt sentinels
      // (background #06060A, text #F4F1E9, accent #6E56F7, gold #E8B96A) —
      // documented upstream collision. Const-canonicalisation merges those two
      // into a single instance, so the unique count is 5, not 6. Asserting
      // >= 5 keeps the contract while honoring the source data.
      final unique = <AppPalette>{
        for (final name in AppPaletteName.values) name.resolve(),
      };
      expect(unique.length, greaterThanOrEqualTo(5));
    });

    test('noirCobalt sentinel hex values are exact (Req 2.2)', () {
      final p = AppPaletteName.noirCobalt.resolve();
      expect(p.background, const Color(0xFF06060A));
      expect(p.text, const Color(0xFFF4F1E9));
      expect(p.accent, const Color(0xFF6E56F7));
      expect(p.live, const Color(0xFFFF3B5C));
      expect(p.gold, const Color(0xFFE8B96A));
    });

    test('displayName returns human-readable strings for every palette', () {
      // Verify the displayName extension exists and returns non-empty strings.
      for (final name in AppPaletteName.values) {
        expect(name.displayName, isNotEmpty);
      }
      // Spot-check two
      expect(AppPaletteName.noirCobalt.displayName, 'Noir Cobalt');
      expect(AppPaletteName.crimsonReel.displayName, 'Crimson Reel');
    });
  });
}
