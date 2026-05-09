// Regression test protecting closed `home-grid-optimization` spec
// invariant from accidental modification by `home-cinematic-redesign` impl.
//
// `pickColumns(double screenW) -> int` from `_grid_tokens.dart` is a
// pure function with three documented thresholds:
//   - screenW <  1280 → 3 columns
//   - 1280 ≤ screenW < 2560 → 4 columns
//   - screenW ≥ 2560 → 5 columns
//
// This test pins the boundaries at 1280 / 2560 / 3840 (typical TV widths).
// If a future cinematic-spec author accidentally edits `_grid_tokens.dart`,
// this test fails immediately and signals re-validate of the closed spec
// (Req 10.3, 12.3 of `home-cinematic-redesign`).

import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/widgets/_grid_tokens.dart';

void main() {
  group('pickColumns regression (closed home-grid-optimization invariant)', () {
    test('1279 (just below 1280 threshold) → 3 columns', () {
      expect(pickColumns(1279), 3);
    });

    test('1280 (at 1280 threshold) → 4 columns', () {
      expect(pickColumns(1280), 4);
    });

    test('2559 (just below 2560 threshold) → 4 columns', () {
      expect(pickColumns(2559), 4);
    });

    test('2560 (at 2560 threshold) → 5 columns', () {
      expect(pickColumns(2560), 5);
    });

    test('3840 (typical 4K TV) → 5 columns', () {
      expect(pickColumns(3840), 5);
    });
  });
}
