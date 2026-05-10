// Pure data types for the cyrillic / latin on-screen keyboard.
//
// This file deliberately has no imports beyond the Dart SDK (and we don't even
// need that here — every type is built-in). It is consumed by:
//   * `keyboard_layouts.dart` — pure const matrices of glyph / sentinel strings.
//   * `cyrillic_keyboard.dart` — widget that maps cells to `KeyboardKey`s.
//   * `search_controller.dart` — exhaustive `switch` over `KeyboardKey`.
//
// Maps to Req 2.1, 2.2, 2.5 of the `search-screen` spec.

/// Active locale of the on-screen keyboard.
///
/// Toggled by the `LocaleToggle` utility key. The current locale selects which
/// 6×6 matrix is rendered (see `keyboardLayout(...)` in `keyboard_layouts.dart`).
enum KeyboardLocale { ru, en }

/// Sealed hierarchy describing a single key on the on-screen keyboard.
///
/// The hierarchy is intentionally narrow so the search controller can
/// exhaustively dispatch on it via a sealed `switch`:
///
/// ```dart
/// switch (key) {
///   case Char(:final glyph): _query += glyph;
///   case Space():            _query += ' ';
///   case Backspace():        _backspace();
///   case LocaleToggle():     _toggleLocale();
/// }
/// ```
///
/// New variants must be added here AND in every `switch`-site that pattern-matches
/// `KeyboardKey` — the compiler will surface those sites as errors.
sealed class KeyboardKey {
  const KeyboardKey();
}

/// A printable character key (e.g. `'А'`, `'B'`, `'-'`, `'1'`).
final class Char extends KeyboardKey {
  const Char(this.glyph);

  /// The exact glyph appended to the query when this key is activated.
  final String glyph;
}

/// Inserts a single space character into the query.
final class Space extends KeyboardKey {
  const Space();
}

/// Removes the last code unit from the query (no-op when query is empty).
final class Backspace extends KeyboardKey {
  const Backspace();
}

/// Toggles `KeyboardLocale.ru` ↔ `KeyboardLocale.en`.
final class LocaleToggle extends KeyboardKey {
  const LocaleToggle();
}
