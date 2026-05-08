import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/features/home/widgets/_grid_tokens.dart';

void main() {
  group('pickColumns boundary values', () {
    test('screenW just below 1280 returns 3', () {
      expect(pickColumns(1279), 3);
    });

    test('screenW exactly 1280 returns 4', () {
      expect(pickColumns(1280), 4);
    });

    test('screenW exactly 2560 returns 5', () {
      expect(pickColumns(2560), 5);
    });
  });
}
