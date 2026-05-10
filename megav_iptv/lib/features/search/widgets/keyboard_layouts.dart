// Pure-const data matrices for the on-screen keyboard.
//
// Each matrix is exactly 6 rows × 6 columns. Cells are either a printable
// glyph string OR one of three utility sentinels rendered specially by
// `cyrillic_keyboard.dart`:
//
//   'SP' → Space
//   'BS' → Backspace
//   'LT' → LocaleToggle
//
// The widget translates sentinel strings into the corresponding `KeyboardKey`
// subclass from `keyboard_key.dart`. Keep the sentinel set in sync with the
// sealed hierarchy there.
//
// Pure data — no imports. Maps to Req 2.1, 2.2, 2.5.

import 'keyboard_key.dart';

/// Russian (cyrillic) 6×6 layout.
///
/// Rows 0..4 are alphabet glyphs in alphabetical order; row 5 finishes the
/// alphabet (`Э`, `Ю`, `Я`) and places the three utility keys in columns 3..5.
const List<List<String>> kKeyboardRu = [
  ['А', 'Б', 'В', 'Г', 'Д', 'Е'],
  ['Ё', 'Ж', 'З', 'И', 'Й', 'К'],
  ['Л', 'М', 'Н', 'О', 'П', 'Р'],
  ['С', 'Т', 'У', 'Ф', 'Х', 'Ц'],
  ['Ч', 'Ш', 'Щ', 'Ъ', 'Ы', 'Ь'],
  ['Э', 'Ю', 'Я', 'SP', 'BS', 'LT'],
];

/// Latin 6×6 layout.
///
/// Rows 0..3 are A..X. Row 4 finishes the alphabet (`Y`, `Z`) and adds four
/// punctuation glyphs commonly typed in channel names (`-`, `.`, `,`, `_`).
/// Row 5 mixes two digits (`1`, `0`) with the universal slash (`/`) used in
/// channel names like `24/7`, then the three utility sentinels in columns 3..5.
/// 6×6 with `SP`/`BS`/`LT` in the last row is the invariant the keyboard widget
/// relies on (Req 2.5).
const List<List<String>> kKeyboardEn = [
  ['A', 'B', 'C', 'D', 'E', 'F'],
  ['G', 'H', 'I', 'J', 'K', 'L'],
  ['M', 'N', 'O', 'P', 'Q', 'R'],
  ['S', 'T', 'U', 'V', 'W', 'X'],
  ['Y', 'Z', '-', '.', ',', '_'],
  ['1', '0', '/', 'SP', 'BS', 'LT'],
];

/// Returns the matrix that corresponds to [locale].
///
/// The returned list is the const top-level matrix; callers must not mutate it.
List<List<String>> keyboardLayout(KeyboardLocale locale) => locale == KeyboardLocale.ru ? kKeyboardRu : kKeyboardEn;
