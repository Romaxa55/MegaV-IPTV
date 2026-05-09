import 'package:flutter/material.dart' hide Chip;
import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/ui/atoms/atoms.dart';

void main() {
  group('MvTrack (T-MvTrack-1)', () {
    testWidgets('progress: 0.5 → AnimatedFractionallySizedBox.widthFactor approaches 0.5', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox(width: 200, child: MvTrack(progress: 0.5)))),
      );
      await tester.pump(const Duration(milliseconds: 300)); // settle animation
      final box = tester.widget<AnimatedFractionallySizedBox>(
        find.byType(AnimatedFractionallySizedBox),
      );
      expect(box.widthFactor, closeTo(0.5, 0.001));
    });

    testWidgets('progress: 1.5 → clamped to 1.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox(width: 200, child: MvTrack(progress: 1.5)))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final box = tester.widget<AnimatedFractionallySizedBox>(
        find.byType(AnimatedFractionallySizedBox),
      );
      expect(box.widthFactor, closeTo(1.0, 0.001));
    });

    testWidgets('progress: -0.3 → clamped to 0.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(width: 200, child: MvTrack(progress: -0.3))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final box = tester.widget<AnimatedFractionallySizedBox>(
        find.byType(AnimatedFractionallySizedBox),
      );
      expect(box.widthFactor, closeTo(0.0, 0.001));
    });
  });
}
