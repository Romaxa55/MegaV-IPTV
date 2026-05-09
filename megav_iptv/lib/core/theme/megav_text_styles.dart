import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// Typed text-style container plugged into [ThemeData] as a [ThemeExtension].
///
/// Holds the five canonical text styles used across MegaV IPTV screens:
/// [displayItalic], [displayLarge] (editorial display serif), [bodyDefault],
/// [bodyDim] (UI sans), and [metaMono] (uppercase monospace metadata).
///
/// The factory [MegaVTextStyles.cinema] builds the `font-cinema` pair for
/// the Russian locale: Cormorant Garamond for display, Golos Text for body,
/// JetBrains Mono for metadata. All three families have full Cyrillic
/// coverage (Requirement 4.1, 4.2). Italic display capability is preserved
/// on [displayItalic] only — body/EPG copy stays upright (Req 4.3, 4.4).
///
/// The [google_fonts] package is already a project dependency
/// (`pubspec.yaml`), so no new packages are introduced (Req 4.5).
///
/// Consumers should reach styles through the [MegaVThemeAccess.megavText]
/// extension getter on [ThemeData], e.g.
/// `Theme.of(context).megavText.displayItalic` (Req 4.6).
@immutable
class MegaVTextStyles extends ThemeExtension<MegaVTextStyles> {
  const MegaVTextStyles({
    required this.displayItalic,
    required this.displayLarge,
    required this.bodyDefault,
    required this.bodyDim,
    required this.metaMono,
  });

  /// Italic editorial display style (e.g. hero headings).
  final TextStyle displayItalic;

  /// Upright editorial display style (large titles).
  final TextStyle displayLarge;

  /// Default body copy (UI sans, primary text color).
  final TextStyle bodyDefault;

  /// Dimmed body copy (UI sans, secondary text color).
  final TextStyle bodyDim;

  /// Metadata / eyebrow style (monospace, uppercase letter-spacing,
  /// muted color).
  final TextStyle metaMono;

  @override
  MegaVTextStyles copyWith({
    TextStyle? displayItalic,
    TextStyle? displayLarge,
    TextStyle? bodyDefault,
    TextStyle? bodyDim,
    TextStyle? metaMono,
  }) {
    return MegaVTextStyles(
      displayItalic: displayItalic ?? this.displayItalic,
      displayLarge: displayLarge ?? this.displayLarge,
      bodyDefault: bodyDefault ?? this.bodyDefault,
      bodyDim: bodyDim ?? this.bodyDim,
      metaMono: metaMono ?? this.metaMono,
    );
  }

  @override
  MegaVTextStyles lerp(ThemeExtension<MegaVTextStyles>? other, double t) {
    // Discrete style sets — no interpolation needed. Snap to `other` past the
    // halfway point, matching how palette switches read as instantaneous.
    if (other is! MegaVTextStyles) return this;
    return t < 0.5 ? this : other;
  }

  /// Builds the `font-cinema` pair (Cormorant Garamond + Golos Text +
  /// JetBrains Mono) wired up to the supplied [palette].
  ///
  /// Numeric values come from the design handoff bundle's `styles.css`:
  /// - `.mv-section-title h3` — display 32px / weight 500 (used as a
  ///   conservative ceiling; the spec mandates a larger 96/64px display
  ///   tier for hero headings, kept here per design.md).
  /// - `.mv-poster .pr-title` — body 14px / weight 600.
  /// - `.mv-chip` — meta 11px / weight 600 / letter-spacing 0.08em /
  ///   uppercase.
  /// - `.mv-poster .pr-sub` — meta 10px / letter-spacing 0.08em.
  ///
  /// Where `styles.css` does not declare a hero display tier, design.md
  /// values (96px italic, 64px large) are used (Requirement 4.1, 4.2, 4.3).
  ///
  /// Letter-spacing in Flutter is logical pixels, not em — `0.08em` is
  /// converted by multiplying by the font size (e.g. `0.08 * 11 = 0.88`).
  factory MegaVTextStyles.cinema(AppPalette palette) {
    const double metaFontSize = 11;
    return MegaVTextStyles(
      displayItalic: GoogleFonts.cormorantGaramond(
        fontSize: 96,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w600,
        height: 1.0,
        color: palette.text,
      ),
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 64,
        fontWeight: FontWeight.w600,
        height: 1.05,
        color: palette.text,
      ),
      bodyDefault: GoogleFonts.golosText(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4, color: palette.text),
      bodyDim: GoogleFonts.golosText(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: palette.textDim),
      metaMono: GoogleFonts.jetBrainsMono(
        fontSize: metaFontSize,
        fontWeight: FontWeight.w500,
        // 0.08em equivalent in logical pixels at this font size.
        letterSpacing: 0.08 * metaFontSize,
        height: 1.2,
        color: palette.textMute,
      ),
    );
  }
}

/// Convenience accessor: `Theme.of(context).megavText.displayItalic`.
///
/// Throws if [MegaVTextStyles] is not registered as a [ThemeExtension] on
/// the current [ThemeData] — i.e. the application failed to call
/// `appTheme(palette)` (task 2.4) which is responsible for registering the
/// extension. This intentionally fails loudly rather than returning a
/// silent fallback (Req 4.6).
extension MegaVThemeAccess on ThemeData {
  MegaVTextStyles get megavText => extension<MegaVTextStyles>()!;
}
