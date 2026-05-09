import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Enumeration of all named palettes shipped with the design system.
///
/// Order is fixed and corresponds to the design handoff bundle
/// (`/.kiro/design/megav-iptv-handoff/project/themes.css` and
/// `cinematic-v2.jsx` PALETTES list). Iteration order is also the order
/// expected by a settings picker UI (`AppPaletteName.values`).
///
/// Default palette is `noirCobalt` — see Requirement 1.5.
enum AppPaletteName { plum, ivory, noirCobalt, pitch, crimsonReel, modern }

// =============================================================================
// Palette constants
//
// Hex values are translated faithfully from the design handoff bundle
// (`themes.css`). Where a CSS theme block does not declare a token, the
// substitution is documented with an inline `///` comment above the field.
//
// Alpha encoding for `Color(0xAARRGGBB)`:
//   0.08 → 0x14   0.10 → 0x1A   0.12 → 0x1F   0.14 → 0x24
//   0.16 → 0x29   0.18 → 0x2E   0.22 → 0x38   0.24 → 0x3D
//   0.35 → 0x59   0.38 → 0x61   0.40 → 0x66   0.45 → 0x73
//   0.50 → 0x80   0.55 → 0x8C   0.62 → 0x9E   0.65 → 0xA6
// =============================================================================

/// Midnight Plum — dark warm-cream + purple accent.
///
/// Source: `themes.css` `.theme-plum`. Note: these values intentionally
/// coincide with `_noirCobalt`'s sentinel values (Req 2.2 sentinel hexes),
/// because the design handoff and the spec converge on the same dark-plum
/// look as both the legacy plum and the new noir-cobalt default. The two
/// are kept as distinct enum entries so a settings picker can still expose
/// "Midnight Plum" as a named option per `cinematic-v2.jsx` PALETTES.
const AppPalette _plum = AppPalette(
  background: Color(0xFF06060A),
  backgroundWarm: Color(0xFF0A0809),
  surface1: Color(0xFF0F0F14),
  surface2: Color(0xFF15151C),
  line: Color(0x14FFF0DC), // rgba(255,240,220,0.08)
  lineStrong: Color(0x29FFF0DC), // rgba(255,240,220,0.16)
  text: Color(0xFFF4F1E9),
  textDim: Color(0x9EF4F1E9), // 0.62 alpha
  textMute: Color(0x61F4F1E9), // 0.38 alpha
  accent: Color(0xFF6E56F7),
  accentGlow: Color(0x736E56F7), // rgba(110,86,247,0.45)
  accentSoft: Color(0x296E56F7), // rgba(110,86,247,0.16)
  gold: Color(0xFFE8B96A),
  goldSoft: Color(0x29E8B96A), // rgba(232,185,106,0.16)
  /// CSS `.theme-plum` does not declare `--live`. Substituted with the
  /// design system's canonical live red (#FF3B5C) used by `_noirCobalt`.
  live: Color(0xFFFF3B5C),

  /// CSS `.theme-plum` does not declare `--live-soft`. Substituted at 0.18
  /// alpha of the `live` color.
  liveSoft: Color(0x2EFF3B5C),

  /// CSS `.theme-plum` does not declare `--good`. Substituted with the
  /// design system's canonical positive teal (#22D3A8).
  good: Color(0xFF22D3A8),
);

/// Ivory Cinema — warm light theme with burnt-orange accent.
///
/// Source: `themes.css` `.theme-ivory`.
const AppPalette _ivory = AppPalette(
  background: Color(0xFFF3EEE3),
  backgroundWarm: Color(0xFFEBE5D6),
  surface1: Color(0xFFE8E1CF),
  surface2: Color(0xFFDDD5C0),
  line: Color(0x1F26180E), // rgba(38,24,14,0.12)
  lineStrong: Color(0x3D26180E), // rgba(38,24,14,0.24)
  text: Color(0xFF1A0F08),
  textDim: Color(0xA61A0F08), // 0.65 alpha
  textMute: Color(0x611A0F08), // 0.38 alpha
  accent: Color(0xFFC9612C),
  accentGlow: Color(0x59C9612C), // rgba(201,97,44,0.35)
  accentSoft: Color(0x24C9612C), // rgba(201,97,44,0.14)
  gold: Color(0xFF8A5A1C),
  goldSoft: Color(0x248A5A1C), // rgba(138,90,28,0.14)
  /// CSS `.theme-ivory` does not declare `--live`. Substituted with a
  /// deep crimson (#B02A1F) that reads as semantic red on a warm light
  /// background without clashing with the burnt-orange accent.
  live: Color(0xFFB02A1F),

  /// CSS `.theme-ivory` does not declare `--live-soft`. Substituted at
  /// 0.16 alpha of the `live` color.
  liveSoft: Color(0x29B02A1F),

  /// CSS `.theme-ivory` does not declare `--good`. Substituted with a
  /// deep moss green (#2E7D55) that harmonises with the warm ivory base.
  good: Color(0xFF2E7D55),
);

/// Noir Cobalt — DEFAULT palette. Dark surfaces, warm-cream text,
/// purple accent, gold ratings, magenta-red live.
///
/// Sentinel hex values per `tasks.md` task 1.3 and Requirement 2.2.
/// Coincides with CSS `.theme-plum` palette in the design handoff bundle.
const AppPalette _noirCobalt = AppPalette(
  background: Color(0xFF06060A),
  backgroundWarm: Color(0xFF0A0809),
  surface1: Color(0xFF0F0F14),
  surface2: Color(0xFF15151C),
  line: Color(0x14FFF0DC), // rgba(255,240,220,0.08)
  lineStrong: Color(0x29FFF0DC), // rgba(255,240,220,0.16)
  text: Color(0xFFF4F1E9), // warm cream — Req 2.2
  textDim: Color(0x9EF4F1E9), // 0.62 alpha
  textMute: Color(0x61F4F1E9), // 0.38 alpha
  accent: Color(0xFF6E56F7),
  accentGlow: Color(0x736E56F7), // 0.45 alpha
  accentSoft: Color(0x296E56F7), // 0.16 alpha
  gold: Color(0xFFE8B96A),
  goldSoft: Color(0x29E8B96A), // 0.16 alpha
  live: Color(0xFFFF3B5C),
  liveSoft: Color(0x2EFF3B5C), // 0.18 alpha
  good: Color(0xFF22D3A8),
);

/// Pitch & Ink — pure black + white with single red accent.
///
/// Source: `themes.css` `.theme-pitch`. Monochromatic by design — `gold`
/// is white per CSS, not a chromatic gold.
const AppPalette _pitch = AppPalette(
  background: Color(0xFF000000),
  backgroundWarm: Color(0xFF060606),
  surface1: Color(0xFF0A0A0A),
  surface2: Color(0xFF111111),
  line: Color(0x1AFFFFFF), // rgba(255,255,255,0.10)
  lineStrong: Color(0x3DFFFFFF), // rgba(255,255,255,0.24)
  text: Color(0xFFFFFFFF),
  textDim: Color(0x9EFFFFFF), // 0.62 alpha
  textMute: Color(0x66FFFFFF), // 0.40 alpha
  accent: Color(0xFFFF3B41),
  accentGlow: Color(0x8CFF3B41), // rgba(255,59,65,0.55)
  accentSoft: Color(0x29FF3B41), // rgba(255,59,65,0.16)
  gold: Color(0xFFFFFFFF), // CSS `--gold: #fff`
  goldSoft: Color(0x1FFFFFFF), // rgba(255,255,255,0.12)
  /// CSS `.theme-pitch` does not declare `--live` separately from `--accent`.
  /// Substituted with the same red accent (#FF3B41) — pitch is mono by design.
  live: Color(0xFFFF3B41),

  /// CSS `.theme-pitch` does not declare `--live-soft`. Substituted at
  /// 0.16 alpha of the `live` color.
  liveSoft: Color(0x29FF3B41),

  /// CSS `.theme-pitch` does not declare `--good`. Substituted with white
  /// (#FFFFFF) — pitch is intentionally monochromatic; success states use
  /// the same neutral that the rest of the palette uses for emphasis.
  good: Color(0xFFFFFFFF),
);

/// Crimson Reel — film-noir red + ochre.
///
/// Source: `themes.css` `.theme-crimson`.
const AppPalette _crimsonReel = AppPalette(
  background: Color(0xFF0A0608),
  backgroundWarm: Color(0xFF100709),
  surface1: Color(0xFF14090C),
  surface2: Color(0xFF1C0C10),
  line: Color(0x14FFC8C8), // rgba(255,200,200,0.08)
  lineStrong: Color(0x2EFFC8C8), // rgba(255,200,200,0.18)
  text: Color(0xFFF6EDE9),
  textDim: Color(0x9EF6EDE9), // 0.62 alpha
  textMute: Color(0x61F6EDE9), // 0.38 alpha
  accent: Color(0xFFE5424A),
  accentGlow: Color(0x80E5424A), // rgba(229,66,74,0.5)
  accentSoft: Color(0x29E5424A), // rgba(229,66,74,0.16)
  gold: Color(0xFFF2A65A),
  goldSoft: Color(0x24F2A65A), // rgba(242,166,90,0.14)
  /// CSS `.theme-crimson` does not declare `--live` separately from
  /// `--accent`. Substituted with the same red (#E5424A) — the palette's
  /// dramatic red IS the live signal in this theme.
  live: Color(0xFFE5424A),

  /// CSS `.theme-crimson` does not declare `--live-soft`. Substituted at
  /// 0.16 alpha of the `live` color.
  liveSoft: Color(0x29E5424A),

  /// CSS `.theme-crimson` does not declare `--good`. Substituted with the
  /// palette's ochre gold (#F2A65A) — fits the noir-film aesthetic where
  /// positive states read as warm amber rather than green.
  good: Color(0xFFF2A65A),
);

/// Modern TV — clean cobalt-blue surface for the Golos Text font pair.
///
/// No `theme-modern` block exists in `themes.css`. The design handoff
/// (`MegaV IPTV - Полный обзор.html` and other screen mockups) consistently
/// pairs `theme-cobalt` with `font-modern` for the "Modern TV" presentation,
/// so this palette mirrors CSS `.theme-cobalt` verbatim.
const AppPalette _modern = AppPalette(
  background: Color(0xFF06080F),
  backgroundWarm: Color(0xFF080B18),
  surface1: Color(0xFF0E1322),
  surface2: Color(0xFF131A2E),
  line: Color(0x1AB4C8FF), // rgba(180,200,255,0.10)
  lineStrong: Color(0x38B4C8FF), // rgba(180,200,255,0.22)
  text: Color(0xFFE8EEFB),
  textDim: Color(0x9EE8EEFB), // 0.62 alpha
  textMute: Color(0x61E8EEFB), // 0.38 alpha
  accent: Color(0xFF3D5DFF),
  accentGlow: Color(0x803D5DFF), // rgba(61,93,255,0.5)
  accentSoft: Color(0x2E3D5DFF), // rgba(61,93,255,0.18)
  gold: Color(0xFF9EC5FF),
  goldSoft: Color(0x299EC5FF), // rgba(158,197,255,0.16)
  /// CSS `.theme-cobalt` does not declare `--live`. Substituted with the
  /// design system's canonical live red (#FF3B5C) — same as `_noirCobalt`.
  live: Color(0xFFFF3B5C),

  /// CSS `.theme-cobalt` does not declare `--live-soft`. Substituted at
  /// 0.18 alpha of the `live` color.
  liveSoft: Color(0x2EFF3B5C),

  /// CSS `.theme-cobalt` does not declare `--good`. Substituted with the
  /// design system's canonical positive teal (#22D3A8).
  good: Color(0xFF22D3A8),
);

// =============================================================================
// Resolver extension
// =============================================================================

/// Resolves an [AppPaletteName] into its corresponding [AppPalette]
/// instance and exposes a human-readable display label.
extension AppPaletteResolver on AppPaletteName {
  /// Returns the const [AppPalette] instance for this enum value.
  ///
  /// Switch is exhaustive — Dart's exhaustive enum switch makes a `default:`
  /// clause unnecessary, and any future addition to [AppPaletteName] will
  /// surface as an analyzer error here.
  AppPalette resolve() {
    switch (this) {
      case AppPaletteName.plum:
        return _plum;
      case AppPaletteName.ivory:
        return _ivory;
      case AppPaletteName.noirCobalt:
        return _noirCobalt;
      case AppPaletteName.pitch:
        return _pitch;
      case AppPaletteName.crimsonReel:
        return _crimsonReel;
      case AppPaletteName.modern:
        return _modern;
    }
  }

  /// Human-readable display name for use in settings UI.
  String get displayName {
    switch (this) {
      case AppPaletteName.plum:
        return 'Plum';
      case AppPaletteName.ivory:
        return 'Ivory';
      case AppPaletteName.noirCobalt:
        return 'Noir Cobalt';
      case AppPaletteName.pitch:
        return 'Pitch';
      case AppPaletteName.crimsonReel:
        return 'Crimson Reel';
      case AppPaletteName.modern:
        return 'Modern';
    }
  }
}
