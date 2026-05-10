import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/search/widgets/search_input.dart';

// Widget tests for [SearchInput] (task 10.4, requirements 4.1, 4.2, 4.3, 4.4).
//
// Two assertions:
//   1. Empty `query` renders the placeholder string `'Найти что-то стоящее'`.
//   2. Non-empty `query` renders the query text AND a `RepaintBoundary`
//      that wraps the blinking caret — the caret implementation lives
//      inside `FadeTransition` (Req 4.3, 9.3 — the boundary keeps the
//      caret repaint local).
//
// Wrapper convention mirrors the EPG widget tests.

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

void main() {
  testWidgets('Test A — empty query renders placeholder text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(child: const SearchInput(query: '')));
    // Two pumps: ScreenUtilInit on the first, the widget body on the
    // second. We do not pumpAndSettle because the caret AnimationController
    // is `repeat(reverse: true)` and would never settle.
    await tester.pump();
    await tester.pump();

    expect(find.text('Найти что-то стоящее'), findsOneWidget);
  });

  testWidgets(
    'Test B — non-empty query renders query text + RepaintBoundary-wrapped FadeTransition caret',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(child: const SearchInput(query: 'тест')));
      await tester.pump();
      await tester.pump();

      // The query is rendered.
      expect(find.text('тест'), findsOneWidget);

      // The caret lives inside `RepaintBoundary > FadeTransition >
      // Container(width: 3.w, ...)`. We verify the boundary→FadeTransition
      // chain explicitly per Req 4.3 / 9.3.
      final caretBoundary = find.descendant(
        of: find.byType(RepaintBoundary),
        matching: find.byType(FadeTransition),
      );
      expect(caretBoundary, findsAtLeastNWidgets(1));
    },
  );
}
