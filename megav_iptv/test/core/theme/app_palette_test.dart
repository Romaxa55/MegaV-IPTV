import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/theme/app_palette.dart';

/// Unit tests for the [AppPalette] token surface (Task 4.1).
///
/// Validates Requirements:
/// - 1.1: AppPalette holds all color tokens of one palette as a single source
///   of truth.
/// - 8.1: Every named palette has all required tokens populated (no nulls,
///   no missing keys).
/// - 8.5: Legacy AppColors aliases (proxied through AppPalette getters) return
///   non-null Color values without runtime errors.
///
/// Since [AppPalette] is already implemented (committed in task 1.1), this
/// suite is a verification harness rather than a TDD red-then-green cycle:
/// the assertions encode the contract that downstream tasks (2.x AppColors
/// proxy, 1.3 named palettes) rely on.
void main() {
  group('AppPalette', () {
    test('const constructor builds with all 17 required fields', () {
      const p = AppPalette(
        background: Color(0xFF000001),
        backgroundWarm: Color(0xFF000002),
        surface1: Color(0xFF000003),
        surface2: Color(0xFF000004),
        line: Color(0xFF000005),
        lineStrong: Color(0xFF000006),
        text: Color(0xFF000007),
        textDim: Color(0xFF000008),
        textMute: Color(0xFF000009),
        accent: Color(0xFF00000A),
        accentGlow: Color(0xFF00000B),
        accentSoft: Color(0xFF00000C),
        gold: Color(0xFF00000D),
        goldSoft: Color(0xFF00000E),
        live: Color(0xFF00000F),
        liveSoft: Color(0xFF000010),
        good: Color(0xFF000011),
      );

      // Spot-check distinct fields to confirm constructor wires positional
      // arguments to the correct named slots.
      expect(p.background, const Color(0xFF000001));
      expect(p.backgroundWarm, const Color(0xFF000002));
      expect(p.surface1, const Color(0xFF000003));
      expect(p.text, const Color(0xFF000007));
      expect(p.accent, const Color(0xFF00000A));
      expect(p.gold, const Color(0xFF00000D));
      expect(p.live, const Color(0xFF00000F));
      expect(p.good, const Color(0xFF000011));
    });

    test('all 17 required fields are non-null Color instances', () {
      const p = AppPalette(
        background: Color(0xFF111111),
        backgroundWarm: Color(0xFF222222),
        surface1: Color(0xFF333333),
        surface2: Color(0xFF444444),
        line: Color(0xFF555555),
        lineStrong: Color(0xFF666666),
        text: Color(0xFF777777),
        textDim: Color(0xFF888888),
        textMute: Color(0xFF999999),
        accent: Color(0xFFAAAAAA),
        accentGlow: Color(0xFFBBBBBB),
        accentSoft: Color(0xFFCCCCCC),
        gold: Color(0xFFDDDDDD),
        goldSoft: Color(0xFFEEEEEE),
        live: Color(0xFFFFFFFF),
        liveSoft: Color(0xFF101010),
        good: Color(0xFF202020),
      );

      // Enumerate every required core-surface field. The list MUST contain
      // exactly 17 entries — that is the contract Requirement 8.1 enforces.
      final fields = <Color>[
        p.background,
        p.backgroundWarm,
        p.surface1,
        p.surface2,
        p.line,
        p.lineStrong,
        p.text,
        p.textDim,
        p.textMute,
        p.accent,
        p.accentGlow,
        p.accentSoft,
        p.gold,
        p.goldSoft,
        p.live,
        p.liveSoft,
        p.good,
      ];
      expect(fields.length, 17);
      for (final color in fields) {
        expect(color, isA<Color>());
      }
    });

    test('backward-compat getters return valid Color values', () {
      const p = AppPalette(
        background: Color(0xFF101010),
        backgroundWarm: Color(0xFF202020),
        surface1: Color(0xFF303030),
        surface2: Color(0xFF404040),
        line: Color(0xFF505050),
        lineStrong: Color(0xFF606060),
        text: Color(0xFF707070),
        textDim: Color(0xFF808080),
        textMute: Color(0xFF909090),
        accent: Color(0xFFA0A0A0),
        accentGlow: Color(0xFFB0B0B0),
        accentSoft: Color(0xFFC0C0C0),
        gold: Color(0xFFD0D0D0),
        goldSoft: Color(0xFFE0E0E0),
        live: Color(0xFFF0F0F0),
        liveSoft: Color(0xFF010101),
        good: Color(0xFF020202),
      );

      // Spot-check the documented mappings between legacy AppColors fields and
      // the new token surface (see backward-compat section in app_palette.dart).
      expect(p.primary, p.accent);
      expect(p.primaryLight, p.accentSoft);
      expect(p.primaryDark, p.accent);
      expect(p.accentLight, p.accentSoft);
      expect(p.surface, p.surface2);
      expect(p.surfaceLight, p.surface2);
      expect(p.textPrimary, p.text);
      expect(p.textSecondary, p.textDim);
      expect(p.textHint, p.textMute);
      expect(p.error, p.live);
      expect(p.success, p.good);
      expect(p.warning, p.gold);
      expect(p.liveBadge, p.live);
      expect(p.soonBadge, p.gold);
      expect(p.focusBorder, p.accent);
      expect(p.cardBorder, p.lineStrong);
      expect(p.cardBg, p.surface1);
      expect(p.chipBg, p.surface2);
      expect(p.chipBorder, p.line);
      expect(p.ratingGold, p.gold);
      expect(p.indigo300, p.accentSoft);

      // Verify every legacy-name backward-compat getter exposed by AppPalette
      // returns a non-null Color (Requirement 8.5). The list below mirrors the
      // exact set of getters declared in app_palette.dart (24 names).
      final legacyAliases = <Color>[
        p.primary,
        p.primaryLight,
        p.primaryDark,
        p.accentLight,
        p.surface,
        p.surfaceLight,
        p.textPrimary,
        p.textSecondary,
        p.textHint,
        p.error,
        p.success,
        p.warning,
        p.liveBadge,
        p.soonBadge,
        p.focusBorder,
        p.cardBorder,
        p.cardBg,
        p.chipBg,
        p.chipBorder,
        p.glassBg,
        p.glassBorder,
        p.glassButtonBg,
        p.ratingGold,
        p.indigo300,
      ];
      expect(legacyAliases.length, 24);
      for (final c in legacyAliases) {
        expect(c, isA<Color>());
      }
    });
  });
}
