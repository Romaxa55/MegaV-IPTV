import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_palettes.dart';

/// Backward-compatibility proxy that exposes all legacy `AppColors.X` static
/// fields as runtime getters reading from an active [AppPalette].
///
/// Originally `AppColors` held a fixed set of `static const Color` fields with
/// hard-coded indigo/teal hexes. Task 2.3 rewires every legacy name into a
/// static getter that reads from a swappable [AppPalette] instance, so the
/// app can switch palettes at runtime (Req 1.4 / Req 2.1) without changing
/// any call-site (Req 2.2).
///
/// All 26 legacy field names from the head version of this file are preserved
/// — nothing was renamed or removed. The mapping from legacy name to the
/// canonical token surface is defined in `AppPalette`'s backward-compat
/// getters (see `app_palette.dart`).
///
/// Default active palette is Noir Cobalt (Req 1.5 / Req 5.4). `app_theme.dart`
/// (task 2.4) and the `MaterialApp.builder` (task 3.1) call
/// [setActivePalette] on every rebuild so the active palette tracks the
/// `themeProvider` state.
class AppColors {
  AppColors._();

  /// Currently active palette. Defaults to Noir Cobalt per Req 1.5 / 5.4.
  static AppPalette _activePalette = AppPaletteName.noirCobalt.resolve();

  /// Swap the palette read by all legacy `AppColors.X` getters.
  ///
  /// Called from `MaterialApp.builder` on every rebuild driven by the
  /// `themeProvider` (task 3.1), so static reads stay coherent with the
  /// `ThemeData` Riverpod just produced.
  static void setActivePalette(AppPalette p) => _activePalette = p;

  /// Read-only accessor used by tests (e.g. `app_colors_compat_test.dart`)
  /// to assert the proxy is wired to the expected palette.
  static AppPalette get activePalette => _activePalette;

  // ---------------------------------------------------------------------------
  // Legacy field surface — one getter per legacy name. Order mirrors the head
  // version of this file for reviewability.
  // ---------------------------------------------------------------------------

  static Color get primary => _activePalette.primary;
  static Color get primaryLight => _activePalette.primaryLight;
  static Color get primaryDark => _activePalette.primaryDark;

  static Color get accent => _activePalette.accent;
  static Color get accentLight => _activePalette.accentLight;

  static Color get background => _activePalette.background;
  static Color get surface => _activePalette.surface;
  static Color get surfaceLight => _activePalette.surfaceLight;

  static Color get textPrimary => _activePalette.textPrimary;
  static Color get textSecondary => _activePalette.textSecondary;
  static Color get textHint => _activePalette.textHint;

  static Color get error => _activePalette.error;
  static Color get success => _activePalette.success;
  static Color get warning => _activePalette.warning;

  static Color get liveBadge => _activePalette.liveBadge;
  static Color get soonBadge => _activePalette.soonBadge;

  static Color get focusBorder => _activePalette.focusBorder;
  static Color get cardBorder => _activePalette.cardBorder;

  static Color get glassBg => _activePalette.glassBg;
  static Color get glassBorder => _activePalette.glassBorder;
  static Color get glassButtonBg => _activePalette.glassButtonBg;

  static Color get ratingGold => _activePalette.ratingGold;
  static Color get indigo300 => _activePalette.indigo300;

  // Figma tokens — card / chip / glass
  static Color get cardBg => _activePalette.cardBg;
  static Color get chipBg => _activePalette.chipBg;
  static Color get chipBorder => _activePalette.chipBorder;
}

/// Tailwind-aligned typography scale (px values, use with .sp).
///
/// Untouched by task 2.3 — TS holds plain `double` constants and is not
/// affected by the palette swap.
class TS {
  TS._();
  static const double t7 = 7;
  static const double t8 = 8;
  static const double t9 = 9;
  static const double t10 = 10;
  static const double t11 = 11;
  static const double xs = 12;
  static const double sm = 14;
  static const double base = 16;
  static const double lg = 18;
  static const double xl = 20;
  static const double t2xl = 24;
  static const double t3xl = 30;
  static const double t4xl = 36;
}
