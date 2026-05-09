import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/epg/epg_window_provider.dart';

void main() {
  test('EpgWindowKey == sorts channelIds for hash equality', () {
    final from = DateTime(2026, 5, 9);
    final to = from.add(const Duration(hours: 4));
    final a = EpgWindowKey(from: from, to: to, channelIds: [3, 1, 2]);
    final b = EpgWindowKey(from: from, to: to, channelIds: [1, 2, 3]);
    expect(a == b, isTrue);
    expect(a.hashCode, b.hashCode);
  });

  test('EpgWindowKey != for different windows', () {
    final from = DateTime(2026, 5, 9);
    final a = EpgWindowKey(from: from, to: from.add(const Duration(hours: 1)), channelIds: [1]);
    final b = EpgWindowKey(from: from, to: from.add(const Duration(hours: 2)), channelIds: [1]);
    expect(a == b, isFalse);
  });
}
