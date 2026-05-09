import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/theme/app_colors.dart';
import 'package:megav_iptv/core/theme/app_palette.dart';
import 'package:megav_iptv/core/theme/app_palettes.dart';

void main() {
  group('AppColors backward-compat proxy', () {
    test('all 26 legacy field names return non-null Color (default Noir Cobalt)', () {
      // Default _activePalette is noirCobalt — no setActivePalette call
      // needed for this test (Req 1.5/5.4 fallback).
      final aliases = <String, Color>{
        'primary': AppColors.primary,
        'primaryLight': AppColors.primaryLight,
        'primaryDark': AppColors.primaryDark,
        'accent': AppColors.accent,
        'accentLight': AppColors.accentLight,
        'background': AppColors.background,
        'surface': AppColors.surface,
        'surfaceLight': AppColors.surfaceLight,
        'textPrimary': AppColors.textPrimary,
        'textSecondary': AppColors.textSecondary,
        'textHint': AppColors.textHint,
        'error': AppColors.error,
        'success': AppColors.success,
        'warning': AppColors.warning,
        'liveBadge': AppColors.liveBadge,
        'soonBadge': AppColors.soonBadge,
        'focusBorder': AppColors.focusBorder,
        'cardBorder': AppColors.cardBorder,
        'glassBg': AppColors.glassBg,
        'glassBorder': AppColors.glassBorder,
        'glassButtonBg': AppColors.glassButtonBg,
        'ratingGold': AppColors.ratingGold,
        'indigo300': AppColors.indigo300,
        'cardBg': AppColors.cardBg,
        'chipBg': AppColors.chipBg,
        'chipBorder': AppColors.chipBorder,
      };
      expect(aliases.length, 26);
      for (final entry in aliases.entries) {
        expect(entry.value, isA<Color>(), reason: 'alias `${entry.key}` should be a Color');
      }
    });

    test('default activePalette is Noir Cobalt', () {
      // Verify the proxy's default state matches Req 1.5/5.4 even when
      // setActivePalette has not been called.
      // Note: AppColors._activePalette is private, but `activePalette` getter exposes it.
      expect(AppColors.activePalette, isA<AppPalette>());
      expect(AppColors.activePalette.background, const Color(0xFF06060A));
      expect(AppColors.activePalette.text, const Color(0xFFF4F1E9));
    });

    test('setActivePalette switches subsequent reads', () {
      // Capture original to restore later (test isolation)
      final original = AppColors.activePalette;

      AppColors.setActivePalette(AppPaletteName.crimsonReel.resolve());
      // After setActivePalette, AppColors.X aliases must reflect new palette
      expect(AppColors.background,
          AppPaletteName.crimsonReel.resolve().background);
      expect(AppColors.accent, AppPaletteName.crimsonReel.resolve().accent);

      // Restore
      AppColors.setActivePalette(original);
      expect(AppColors.background, original.background);
    });
  });
}
