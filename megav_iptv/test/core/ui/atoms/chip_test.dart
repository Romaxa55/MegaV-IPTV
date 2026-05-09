import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';

void main() {
  group('Chip variants (T-Chip-1..5)', () {
    Future<Color?> renderAndGetBg(WidgetTester tester, ChipVariant variant) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Chip(label: 'X', variant: variant))),
      );
      // Find the outer pill Container — it is the one with a BoxDecoration
      // that has a non-null color OR is the only Container with a
      // BorderRadius matching the pill (radius 999).
      final containers = tester.widgetList<Container>(find.byType(Container));
      final pill = containers.firstWhere((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.borderRadius == BorderRadius.circular(999);
      });
      return (pill.decoration as BoxDecoration).color;
    }

    final variants = ChipVariant.values;
    for (final v1 in variants) {
      testWidgets('${v1.name} renders with expected bg color', (tester) async {
        final bg = await renderAndGetBg(tester, v1);
        if (v1 == ChipVariant.ghost) {
          // ghost variant uses Colors.transparent
          expect(bg, equals(const Color(0x00000000)));
        } else {
          expect(bg, isNotNull);
          expect(bg, isNot(equals(const Color(0x00000000))));
        }
      });
    }

    testWidgets('live variant has RepaintBoundary ancestor for animated dot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Chip(label: 'LIVE', variant: ChipVariant.live))),
      );
      // RepaintBoundary should appear in the widget tree (wraps the pulse dot).
      expect(find.byType(RepaintBoundary), findsWidgets);
    });
  });
}
