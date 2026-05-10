import 'package:flutter/material.dart' hide Chip;
import 'package:flutter/services.dart' hide KeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/perf/perf_safe_widgets.dart';
import 'package:megav_iptv/features/search/widgets/cyrillic_keyboard.dart';
import 'package:megav_iptv/features/search/widgets/keyboard_key.dart';

// Widget tests for [CyrillicKeyboard] (task 10.3, requirements 3.3, 3.7,
// 3.8, 3.9, 12.3, 12.4).
//
// The keyboard is a 6×6 grid of `Focus`-wrapped cells. To assert which
// cell currently holds focus, every cell is keyed with `kb-cell-<r>-<c>`
// in production (testability hook documented in
// `cyrillic_keyboard.dart`). We then look up the corresponding `Focus`
// widget and read its `FocusNode.hasFocus`.
//
// The widget renders an absolute `Transform.scale(1.05)` for the focused
// cell — that's enough to catch focus visually, but we use `hasFocus` for
// determinism.
//
// Wrapper convention mirrors `epg_program_cell_test.dart`: MediaQuery →
// ProviderScope → ScreenUtilInit → MaterialApp.

Widget _harness({required Widget child}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1920, 1080)),
    child: ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(1920, 1080),
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
}

/// True iff the cell at `(r, c)` is currently rendered as the visually
/// focused cell. Reads `SafeFocusRing.isFocused` inside the cell — that
/// flag is the canonical "focused" marker used by the keyboard widget
/// (it is fed from `focusRow == r && focusCol == c`).
///
/// We do *not* rely on `tester.binding.focusManager.primaryFocus` because
/// the production widget intentionally keeps the underlying FocusNode
/// fixed across arrow-key presses — visual focus is driven by `setState`
/// on `focusRow`/`focusCol`, not by reparenting `FocusNode.requestFocus`.
bool _focusAt(WidgetTester tester, int r, int c) {
  final ring = tester.widget<SafeFocusRing>(
    find.descendant(
      of: find.byKey(Key('kb-cell-$r-$c')),
      matching: find.byType(SafeFocusRing),
    ),
  );
  return ring.isFocused;
}

void main() {
  testWidgets(
    'Test A — initialFocus (0,0) + arrowDown moves focus to (1,0)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(
        child: CyrillicKeyboard(
          onKeyPressed: (_) {},
          onExitRight: () {},
          // initialFocus defaults to (0, 0).
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(_focusAt(tester, 0, 0), isTrue, reason: 'autofocus should land on (0,0)');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(_focusAt(tester, 1, 0), isTrue, reason: 'arrowDown from (0,0) should focus (1,0)');
    },
  );

  testWidgets(
    'Test B — initialFocus (5,0) + arrowDown clamps and stays at (5,0)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(
        child: CyrillicKeyboard(
          onKeyPressed: (_) {},
          onExitRight: () {},
          initialFocus: (5, 0),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(_focusAt(tester, 5, 0), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Bottom row is clamped — focus must remain at (5, 0).
      expect(_focusAt(tester, 5, 0), isTrue, reason: 'arrowDown from (5,0) must clamp');
    },
  );

  testWidgets(
    'Test C — initialFocus (0,5) + arrowRight invokes onExitRight exactly once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var exitCount = 0;
      await tester.pumpWidget(_harness(
        child: CyrillicKeyboard(
          onKeyPressed: (_) {},
          onExitRight: () => exitCount += 1,
          initialFocus: (0, 5),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(_focusAt(tester, 0, 5), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(exitCount, 1, reason: 'arrowRight at column 5 must call onExitRight (Req 3.7)');
    },
  );

  testWidgets(
    'Test D — initialFocus (0,0) + select dispatches Char("А") exactly once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final received = <KeyboardKey>[];
      await tester.pumpWidget(_harness(
        child: CyrillicKeyboard(
          onKeyPressed: received.add,
          onExitRight: () {},
        ),
      ));
      await tester.pump();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(received.length, 1);
      expect(received.single, isA<Char>());
      expect((received.single as Char).glyph, 'А');
    },
  );

  testWidgets(
    'Test E — initialFocus (5,3) + select dispatches Space',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final received = <KeyboardKey>[];
      await tester.pumpWidget(_harness(
        child: CyrillicKeyboard(
          onKeyPressed: received.add,
          onExitRight: () {},
          initialFocus: (5, 3), // 'SP' sentinel in kKeyboardRu.
        ),
      ));
      await tester.pump();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(received.length, 1);
      expect(received.single, isA<Space>());
    },
  );
}
