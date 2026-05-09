import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/theme/app_palettes.dart';
import 'package:megav_iptv/core/theme/computed_colors.dart';

void main() {
  group('ComputedColors', () {
    test('T-10: from(palette) returns three distinct non-null Color values (Req 6.1, 6.5)', () {
      final c = ComputedColors.from(AppPaletteName.noirCobalt.resolve());
      expect(c.textTintAccent, isA<Color>());
      expect(c.accentTintText, isA<Color>());
      expect(c.surfaceTintAccent, isA<Color>());
      // Three colors should differ from each other (different mix sources).
      expect(c.textTintAccent, isNot(equals(c.accentTintText)));
      expect(c.textTintAccent, isNot(equals(c.surfaceTintAccent)));
      expect(c.accentTintText, isNot(equals(c.surfaceTintAccent)));
    });

    test('T-11: different palettes produce different mixed colors (Req 6.4, 11.6)', () {
      final noir = ComputedColors.from(AppPaletteName.noirCobalt.resolve());
      final crimson = ComputedColors.from(AppPaletteName.crimsonReel.resolve());
      expect(noir.textTintAccent, isNot(equals(crimson.textTintAccent)));
      expect(noir.accentTintText, isNot(equals(crimson.accentTintText)));
      expect(noir.surfaceTintAccent, isNot(equals(crimson.surfaceTintAccent)));
    });

    test('T-12: deterministic — same palette twice returns identical Colors (Req 6.3)', () {
      final p = AppPaletteName.noirCobalt.resolve();
      final a = ComputedColors.from(p);
      final b = ComputedColors.from(p);
      expect(a.textTintAccent, b.textTintAccent);
      expect(a.accentTintText, b.accentTintText);
      expect(a.surfaceTintAccent, b.surfaceTintAccent);
    });
  });
}
