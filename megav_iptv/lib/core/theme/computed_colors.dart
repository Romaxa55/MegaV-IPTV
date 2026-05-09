import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Pre-mixed Color constants used by hover, pressed, and focus visual
/// states. Replaces CSS `color-mix(in oklab, ...)` which has no Dart
/// equivalent. Mixed via `Color.lerp` in linear-RGB space — gamma-incorrect
/// but visually adequate for the small tint ratios (4-15%) used in the
/// design handoff.
///
/// Usage:
/// ```dart
/// final mixed = ComputedColors.from(palette);
/// // mixed.textTintAccent — text 92% + accent 8%
/// // mixed.accentTintText — accent 92% + text 8%
/// // mixed.surfaceTintAccent — surface1 92% + accent 8%
/// ```
class ComputedColors {
  const ComputedColors._({required this.textTintAccent, required this.accentTintText, required this.surfaceTintAccent});

  final Color textTintAccent;
  final Color accentTintText;
  final Color surfaceTintAccent;

  /// Build a `ComputedColors` from an [AppPalette]. Pure function:
  /// same input always yields the same output. Different palettes
  /// produce visibly different mixed colors (Req 6.4).
  factory ComputedColors.from(AppPalette p) {
    return ComputedColors._(
      textTintAccent: Color.lerp(p.text, p.accent, 0.08)!,
      accentTintText: Color.lerp(p.accent, p.text, 0.08)!,
      surfaceTintAccent: Color.lerp(p.surface1, p.accent, 0.08)!,
    );
  }
}
