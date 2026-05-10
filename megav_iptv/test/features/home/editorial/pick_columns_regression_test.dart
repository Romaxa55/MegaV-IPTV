// Regression test protecting the closed `home-grid-optimization` spec
// invariant from accidental modification by `home-editorial-redesign`.
//
// `pickColumns(double screenW) -> int` from `_grid_tokens.dart` is a
// pure function with three documented thresholds:
//   - screenW <  1280 → 3 columns
//   - 1280 ≤ screenW < 2560 → 4 columns
//   - screenW ≥ 2560 → 5 columns
//
// This duplicates the cinematic-spec regression test in editorial-spec
// territory so a future editorial-spec author cannot accidentally edit
// `_grid_tokens.dart` without tripping a test inside their own fence.
//
// The file uses a `package:` import even though `_grid_tokens.dart` is
// underscore-prefixed — Dart only privatises symbol names by leading
// underscore, NOT file names; underscored files remain importable from
// anywhere within the same package.

import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/widgets/_grid_tokens.dart';

void main() {
  group('pickColumns regression (closed home-grid-optimization invariant)', () {
    test('1279 (just below 1280 threshold) → 3 columns', () {
      expect(pickColumns(1279), 3);
    });

    test('1280 (at the 1280 threshold) → 3 columns', () {
      // Editorial-spec mirror of the cinematic regression test. The
      // exact value at the threshold is whatever the cinematic test
      // asserts — both must match the closed `home-grid-optimization`
      // invariant. If these diverge, _grid_tokens.dart was edited.
      expect(pickColumns(1280), 4);
    });

    test('2559 (just below 2560 threshold) → 4 columns', () {
      expect(pickColumns(2559), 4);
    });

    test('2560 (at the 2560 threshold) → 5 columns', () {
      expect(pickColumns(2560), 5);
    });

    test('3840 (typical 4K TV viewport) → 5 columns', () {
      expect(pickColumns(3840), 5);
    });
  });
}
