import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_palettes.dart';
import 'megav_text_styles.dart';

/// Build a [ThemeData] configured for the supplied [palette].
///
/// Side-effect: calls [AppColors.setActivePalette] so every legacy
/// `AppColors.X` static getter resolves through the same palette as the
/// returned [ThemeData] (Req 2.1 — preserves call-sites in closed specs
/// without modifying any of them).
///
/// The returned [ThemeData] also registers [MegaVTextStyles.cinema] as a
/// [ThemeExtension] so widgets can reach the cinematic typography pair
/// through `Theme.of(context).megavText` (Req 4.1, 4.2, 4.5, 4.6).
///
/// Static `AppColors.X` getters are intentionally exempt from the per-widget
/// rebuild propagation guarantee in Req 7.2 — they are global mutable state
/// updated here on every theme rebuild, which is the documented bridge for
/// callers that have not yet migrated to the [Theme.of] surface.
///
/// The [palette] parameter is optional so legacy zero-arg callers
/// (`appTheme()`, `AppTheme.dark`) keep compiling. The default is
/// [AppPaletteName.noirCobalt] per Req 1.5 / Req 5.4.
ThemeData appTheme([AppPalette? palette]) {
  final p = palette ?? AppPaletteName.noirCobalt.resolve();

  // Side-effect: route every legacy `AppColors.X` getter through this
  // palette so static reads stay coherent with the returned ThemeData.
  AppColors.setActivePalette(p);

  final base = ThemeData(brightness: Brightness.dark);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    headlineLarge: GoogleFonts.inter(color: p.text, fontWeight: FontWeight.bold),
    headlineMedium: GoogleFonts.inter(color: p.text, fontWeight: FontWeight.w600),
    bodyLarge: GoogleFonts.inter(color: p.text),
    bodyMedium: GoogleFonts.inter(color: p.textDim),
    bodySmall: GoogleFonts.inter(color: p.textMute),
  );

  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: p.accent,
    scaffoldBackgroundColor: p.background,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: textTheme,
    colorScheme: ColorScheme.dark(primary: p.accent, secondary: p.accent, surface: p.surface2, error: p.live),
    appBarTheme: AppBarTheme(backgroundColor: p.surface2, elevation: 0, centerTitle: false),
    cardTheme: CardThemeData(
      color: p.surface2,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.accent, width: 2),
      ),
      hintStyle: TextStyle(color: p.textMute),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[MegaVTextStyles.cinema(p)],
  );
}

/// Legacy access surface preserved for call-sites that have not yet been
/// migrated to the top-level [appTheme] function (e.g. `lib/app.dart`,
/// rewired in task 3.1). Delegates to [appTheme] with the default palette.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => appTheme();
}
