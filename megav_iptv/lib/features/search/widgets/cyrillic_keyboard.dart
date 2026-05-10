// On-screen 6×6 D-pad-navigable keyboard for the search screen.
//
// Renders the active 6×6 layout (`keyboardLayout(_locale)`) as a grid of
// `MvKey` keycaps. The currently focused cell is wrapped in
// `SafeFocusRing` and `Transform.scale(1.05)` (Req 3.10, 9.4) — width-static
// scaling avoids the Mali-GPU hot-path issues of `AnimatedContainer.width`
// (Req 9.4 explicitly forbids it).
//
// D-pad navigation rules (Req 3.1–3.10):
//   * arrowUp / arrowDown: clamp focus row inside [0, 5].
//   * arrowLeft on `focusCol > 0`: decrement column. On column 0 → ignored,
//     so the parent decides where focus exits (Req 3.5).
//   * arrowRight on `focusCol < 5`: increment column. On column 5 →
//     `widget.onExitRight()` is called and the event is consumed (Req 3.7).
//   * select / enter: dispatches `widget.onKeyPressed(...)` with the right
//     `KeyboardKey` variant. `LT` toggles `_locale` locally (state) AND
//     forwards `LocaleToggle` upstream so the controller can mirror it.
//
// Maps to Requirements 2.3, 2.4, 2.6, 3.1–3.10, 9.4.

import 'package:flutter/material.dart' hide Chip;
import 'package:flutter/services.dart' hide KeyboardKey;

import 'package:megav_iptv/core/ui/atoms/atoms.dart';

import '../../../core/perf/perf_safe_widgets.dart';
import '../../../core/theme/app_colors.dart';
import 'keyboard_key.dart';
import 'keyboard_layouts.dart';

/// 6×6 on-screen keyboard with D-pad navigation.
///
/// Stateless from the controller's perspective — emits `KeyboardKey` events
/// via [onKeyPressed] and lets the parent decide focus transfer when the user
/// arrows past the right edge ([onExitRight]).
///
/// `initialFocus` is `@visibleForTesting` so widget tests can pump the
/// keyboard with a non-default starting cell (Req 12.3).
class CyrillicKeyboard extends StatefulWidget {
  const CyrillicKeyboard({
    super.key,
    required this.onKeyPressed,
    required this.onExitRight,
    this.locale = KeyboardLocale.ru,
    @visibleForTesting this.initialFocus = (0, 0),
  });

  /// Invoked with the [KeyboardKey] variant produced by the focused cell.
  final void Function(KeyboardKey) onKeyPressed;

  /// Invoked when the user presses arrowRight while focus is on column 5
  /// (Req 3.7). Parent is responsible for transferring focus out of the
  /// keyboard (typically into the results pane).
  final VoidCallback onExitRight;

  /// Initial keyboard locale. Toggled internally via the `LT` utility key —
  /// the parent is informed via `onKeyPressed(const LocaleToggle())` so the
  /// search controller can keep its own copy in sync.
  final KeyboardLocale locale;

  /// `(row, col)` cell that should be auto-focused on first build.
  /// `@visibleForTesting` — production callers should always accept the
  /// default `(0, 0)`.
  @visibleForTesting
  final (int, int) initialFocus;

  @override
  State<CyrillicKeyboard> createState() => _CyrillicKeyboardState();
}

class _CyrillicKeyboardState extends State<CyrillicKeyboard> {
  late int focusRow;
  late int focusCol;
  late KeyboardLocale _locale;

  @override
  void initState() {
    super.initState();
    focusRow = widget.initialFocus.$1;
    focusCol = widget.initialFocus.$2;
    _locale = widget.locale;
  }

  // Translates a sentinel string from `keyboardLayouts.dart` (or a printable
  // glyph) into the human-readable label rendered inside the `MvKey` keycap.
  String _label(String cell) {
    switch (cell) {
      case 'SP':
        return '␣';
      case 'BS':
        return '⌫';
      case 'LT':
        return _locale == KeyboardLocale.ru ? 'EN' : 'RU';
      default:
        return cell;
    }
  }

  // Dispatches the focused cell as a `KeyboardKey` event. `LT` also flips the
  // local `_locale` so the next build renders the toggled matrix; the parent
  // controller is informed via `LocaleToggle` so it can mirror the change.
  void _activate(int r, int c) {
    final cell = keyboardLayout(_locale)[r][c];
    switch (cell) {
      case 'SP':
        widget.onKeyPressed(const Space());
      case 'BS':
        widget.onKeyPressed(const Backspace());
      case 'LT':
        setState(() {
          _locale = _locale == KeyboardLocale.ru ? KeyboardLocale.en : KeyboardLocale.ru;
        });
        widget.onKeyPressed(const LocaleToggle());
      default:
        widget.onKeyPressed(Char(cell));
    }
  }

  KeyEventResult _onKeyEvent(int r, int c, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => focusRow = (focusRow - 1).clamp(0, 5));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => focusRow = (focusRow + 1).clamp(0, 5));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (focusCol > 0) {
        setState(() => focusCol = focusCol - 1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (focusCol < 5) {
        setState(() => focusCol = focusCol + 1);
        return KeyEventResult.handled;
      }
      widget.onExitRight();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _activate(r, c);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _cell(int r, int c) {
    final cell = keyboardLayout(_locale)[r][c];
    final label = _label(cell);
    final focused = focusRow == r && focusCol == c;
    return Padding(
      key: Key('kb-cell-$r-$c'),
      padding: const EdgeInsets.all(4),
      child: Focus(
        autofocus: focused,
        onKeyEvent: (node, event) => _onKeyEvent(r, c, node, event),
        child: SafeFocusRing(
          isFocused: focused,
          child: Transform.scale(
            scale: focused ? 1.05 : 1.0,
            child: MvKey(glyph: label),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Anchor the keyboard's painted rect to the active palette background
      // so the SafeFocusRing's inner shadow (which uses AppColors.background)
      // visually lines up with whatever is behind the widget.
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int r = 0; r < 6; r++)
            Row(mainAxisSize: MainAxisSize.min, children: [for (int c = 0; c < 6; c++) _cell(r, c)]),
        ],
      ),
    );
  }
}
