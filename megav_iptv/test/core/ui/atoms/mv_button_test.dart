import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/perf/perf_safe_widgets.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';

({Color? color, bool hasBorder}) _findButtonDecoration(WidgetTester tester) {
  // The MvButton renders Container -> Material -> InkWell -> Container(shell).
  // The shell Container is the descendant of InkWell. Locate it precisely by
  // walking down from InkWell so we never pick up the outer Material's
  // internal Container.
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(InkWell), matching: find.byType(Container)),
  );
  final dec = container.decoration as BoxDecoration;
  return (color: dec.color, hasBorder: dec.border != null);
}

void main() {
  group('MvButton variants (T-MvButton-1..3)', () {
    testWidgets('primary renders with non-transparent bg', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MvButton.primary(label: 'OK', onPressed: () {}))),
      );
      final dec = _findButtonDecoration(tester);
      expect(dec.color, isNotNull);
      expect(dec.color, isNot(equals(const Color(0x00000000))));
    });

    testWidgets('ghost renders with transparent bg', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MvButton.ghost(label: 'OK', onPressed: () {}))),
      );
      final dec = _findButtonDecoration(tester);
      // Ghost variant uses Colors.transparent (0x00000000) as bg color and
      // has a visible border instead.
      expect(dec.color, equals(const Color(0x00000000)));
      expect(dec.hasBorder, isTrue);
    });

    testWidgets('accent renders with non-transparent bg', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MvButton.accent(label: 'OK', onPressed: () {}))),
      );
      final dec = _findButtonDecoration(tester);
      expect(dec.color, isNotNull);
      expect(dec.color, isNot(equals(const Color(0x00000000))));
    });

    testWidgets('isFocused: true wraps in SafeFocusRing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MvButton.primary(label: 'OK', onPressed: () {}, isFocused: true),
          ),
        ),
      );
      expect(find.byType(SafeFocusRing), findsOneWidget);
    });
  });
}
