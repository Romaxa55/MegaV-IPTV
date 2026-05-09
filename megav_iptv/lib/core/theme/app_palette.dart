import 'package:flutter/material.dart';

/// Instance class holding all color tokens for a single named palette.
///
/// One `AppPalette` corresponds to one named palette (e.g. Noir Cobalt,
/// Crimson Reel). The full list of named palettes lives in `app_palettes.dart`.
///
/// All fields are required and `final Color`, so the class is `const`-
/// constructible and palette instances can be declared as compile-time
/// constants in `app_palettes.dart`.
///
/// Backward-compatibility getters at the bottom of the class map every legacy
/// `AppColors.X` field name onto the new token surface, so the downstream
/// `AppColors` proxy (task 2.3) can write `static Color get X => _resolveActive().X`
/// for every legacy name without losing any call-site.
class AppPalette {
  // ---------------------------------------------------------------------------
  // Core token surface (the single source of truth for one palette).
  // ---------------------------------------------------------------------------

  /// Primary scaffold background (deepest layer).
  final Color background;

  /// Slightly warm-tinted background variant for hero/cinematic surfaces.
  final Color backgroundWarm;

  /// First elevated surface (cards, tiles).
  final Color surface1;

  /// Second elevated surface (inset chips, secondary panels).
  final Color surface2;

  /// Subtle hairline divider / border.
  final Color line;

  /// Stronger divider / border (focus rings, emphasized separators).
  final Color lineStrong;

  /// Primary text color. In Noir Cobalt this is warm cream `#F4F1E9`,
  /// not pure white — by design.
  final Color text;

  /// Dimmed text (~62% alpha of `text`) for secondary copy.
  final Color textDim;

  /// Muted text (~38% alpha of `text`) for hints / captions.
  final Color textMute;

  /// Brand accent (interactive primary, focus highlights).
  final Color accent;

  /// Accent glow used for soft halos behind the focused element.
  final Color accentGlow;

  /// Soft accent fill (chips, pressed-state backgrounds).
  final Color accentSoft;

  /// Gold token used for ratings, premium markers.
  final Color gold;

  /// Soft gold fill (rating chip backgrounds).
  final Color goldSoft;

  /// Live indicator (red badge, "LIVE" pill).
  final Color live;

  /// Soft live fill (live-pill background tint).
  final Color liveSoft;

  /// Positive / success token (e.g. EPG "now playing" success state).
  final Color good;

  const AppPalette({
    required this.background,
    required this.backgroundWarm,
    required this.surface1,
    required this.surface2,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textDim,
    required this.textMute,
    required this.accent,
    required this.accentGlow,
    required this.accentSoft,
    required this.gold,
    required this.goldSoft,
    required this.live,
    required this.liveSoft,
    required this.good,
  });

  // ---------------------------------------------------------------------------
  // Backward-compat computed getters.
  //
  // Every legacy field name from `lib/core/theme/app_colors.dart` (head version)
  // resolves to the closest semantic token here. Task 2.3 will rewrite
  // `AppColors` as a thin proxy that does `static Color get X => _resolveActive().X`,
  // so each legacy name needs to be reachable on this class.
  // ---------------------------------------------------------------------------

  /// Legacy `AppColors.primary` → brand accent.
  Color get primary => accent;

  /// Legacy `AppColors.primaryLight` → softer accent fill (lighter variant).
  Color get primaryLight => accentSoft;

  /// Legacy `AppColors.primaryDark` → no darker accent token; reuse base accent.
  Color get primaryDark => accent;

  /// Legacy `AppColors.accentLight` → soft accent fill (legacy teal-light → soft purple).
  Color get accentLight => accentSoft;

  /// Legacy `AppColors.surface` → second elevated surface.
  Color get surface => surface2;

  /// Legacy `AppColors.surfaceLight` → no third elevation; reuse `surface2`.
  Color get surfaceLight => surface2;

  /// Legacy `AppColors.textPrimary` → primary text.
  Color get textPrimary => text;

  /// Legacy `AppColors.textSecondary` → dimmed text.
  Color get textSecondary => textDim;

  /// Legacy `AppColors.textHint` → muted text.
  Color get textHint => textMute;

  /// Legacy `AppColors.error` → live (red) token.
  Color get error => live;

  /// Legacy `AppColors.success` → good (positive) token.
  Color get success => good;

  /// Legacy `AppColors.warning` → gold token (closest semantic match).
  Color get warning => gold;

  /// Legacy `AppColors.liveBadge` → live token.
  Color get liveBadge => live;

  /// Legacy `AppColors.soonBadge` → gold token (amber-ish badge).
  Color get soonBadge => gold;

  /// Legacy `AppColors.focusBorder` → accent (focus ring color).
  Color get focusBorder => accent;

  /// Legacy `AppColors.cardBorder` → strong divider line.
  Color get cardBorder => lineStrong;

  /// Legacy `AppColors.cardBg` → first elevated surface.
  Color get cardBg => surface1;

  /// Legacy `AppColors.chipBg` → second elevated surface.
  Color get chipBg => surface2;

  /// Legacy `AppColors.chipBorder` → subtle hairline divider.
  Color get chipBorder => line;

  /// Legacy `AppColors.glassBg` → translucent white veneer (~3% alpha).
  /// Kept as a fixed constant since the legacy value was palette-agnostic
  /// (`Colors.white.withValues(alpha: 0.03)`).
  Color get glassBg => const Color(0x08FFFFFF); // ~3% alpha white

  /// Legacy `AppColors.glassBorder` → translucent white border (~6% alpha).
  Color get glassBorder => const Color(0x0FFFFFFF); // ~6% alpha white

  /// Legacy `AppColors.glassButtonBg` → translucent white button fill (~10% alpha).
  Color get glassButtonBg => const Color(0x1AFFFFFF); // ~10% alpha white

  /// Legacy `AppColors.ratingGold` → gold token.
  Color get ratingGold => gold;

  /// Legacy `AppColors.indigo300` → soft accent (closest visual analogue
  /// to the legacy indigo-300 highlight on a purple-accent palette).
  Color get indigo300 => accentSoft;
}
