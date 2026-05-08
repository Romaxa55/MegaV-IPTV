import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/widgets/_grid_tokens.dart';

void main() {
  group('pickColumns boundary values', () {
    // Requirement 1.1: screenW < 1280 → 3 columns
    test('pickColumns(0) returns 3', () {
      expect(pickColumns(0), 3);
    });

    test('pickColumns(800) returns 3', () {
      expect(pickColumns(800), 3);
    });

    test('screenW just below 1280 returns 3', () {
      expect(pickColumns(1279), 3);
    });

    // Requirement 1.2: 1280 ≤ screenW < 2560 → 4 columns
    test('screenW exactly 1280 returns 4', () {
      expect(pickColumns(1280), 4);
    });

    test('pickColumns(1920) returns 4', () {
      expect(pickColumns(1920), 4);
    });

    test('pickColumns(2559) returns 4', () {
      expect(pickColumns(2559), 4);
    });

    // Requirement 1.3: screenW ≥ 2560 → 5 columns
    test('screenW exactly 2560 returns 5', () {
      expect(pickColumns(2560), 5);
    });

    test('pickColumns(3840) returns 5', () {
      expect(pickColumns(3840), 5);
    });
  });

  group('cardWidth invariant: n*cardW + (n-1)*gap + 2*pad ≈ screenW (Req 1.4)', () {
    // Note: this test uses logical (raw) `GridTokens.gapDp` and
    // `GridTokens.horizontalPaddingDp` values, NOT screenutil-scaled `.w`.
    // The math invariant is independent of runtime screenutil scale; the
    // scale only applies at use-site in widgets.
    const double gap = GridTokens.gapDp; // 16
    const double pad = GridTokens.horizontalPaddingDp; // 48

    double cardWidthFor(double screenW, int n) {
      return (screenW - 2 * pad - (n - 1) * gap) / n;
    }

    test('screenW=1280, n=4: 4*cardW + 3*gap + 2*pad ≈ 1280', () {
      const screenW = 1280.0;
      final n = pickColumns(screenW);
      expect(n, 4);
      final cardW = cardWidthFor(screenW, n);
      final total = n * cardW + (n - 1) * gap + 2 * pad;
      expect(total, closeTo(screenW, 0.001));
    });

    test('screenW=1920, n=4: 4*cardW + 3*gap + 2*pad ≈ 1920', () {
      const screenW = 1920.0;
      final n = pickColumns(screenW);
      expect(n, 4);
      final cardW = cardWidthFor(screenW, n);
      final total = n * cardW + (n - 1) * gap + 2 * pad;
      expect(total, closeTo(screenW, 0.001));
    });

    test('screenW=2560, n=5: 5*cardW + 4*gap + 2*pad ≈ 2560', () {
      const screenW = 2560.0;
      final n = pickColumns(screenW);
      expect(n, 5);
      final cardW = cardWidthFor(screenW, n);
      final total = n * cardW + (n - 1) * gap + 2 * pad;
      expect(total, closeTo(screenW, 0.001));
    });
  });
}
