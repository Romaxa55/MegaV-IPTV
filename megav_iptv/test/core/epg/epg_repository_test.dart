import 'package:flutter_test/flutter_test.dart';
import 'package:megav_iptv/core/api/api_client.dart';
import 'package:megav_iptv/core/epg/epg_repository.dart';
import 'package:megav_iptv/core/playlist/models/epg_program.dart';

class _MockApiClient implements ApiClient {
  int callCount = 0;
  final Map<int, List<EpgProgram>> seed;
  _MockApiClient(this.seed);

  @override
  Future<List<EpgProgram>> getUpcomingPrograms(int channelId, {int limit = 10}) async {
    callCount++;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return seed[channelId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('EpgRepository', () {
    test('programmesInWindow returns map keyed by channelId', () async {
      final now = DateTime.now();
      final program = EpgProgram(
        id: 1, channelId: 10, title: 'Show',
        start: now, end: now.add(const Duration(hours: 1)),
      );
      final api = _MockApiClient({10: [program]});
      final repo = EpgRepository(api);

      final result = await repo.programmesInWindow(
        now.subtract(const Duration(hours: 1)),
        now.add(const Duration(hours: 2)),
        [10],
      );
      expect(result.keys, [10]);
      expect(result[10]!.length, 1);
    });

    test('TTL cache prevents duplicate fetches within 60s', () async {
      final now = DateTime.now();
      final api = _MockApiClient({10: const []});
      final repo = EpgRepository(api);

      await repo.programmesInWindow(now, now.add(const Duration(hours: 1)), [10]);
      await repo.programmesInWindow(now, now.add(const Duration(hours: 1)), [10]);
      expect(api.callCount, 1, reason: 'Second call should hit cache');
    });

    test('filters programmes outside window', () async {
      final now = DateTime.now();
      final inWindow = EpgProgram(
        id: 1, channelId: 10, title: 'In',
        start: now, end: now.add(const Duration(minutes: 30)),
      );
      final outWindow = EpgProgram(
        id: 2, channelId: 10, title: 'Out',
        start: now.add(const Duration(hours: 5)),
        end: now.add(const Duration(hours: 6)),
      );
      final api = _MockApiClient({10: [inWindow, outWindow]});
      final repo = EpgRepository(api);

      final result = await repo.programmesInWindow(
        now,
        now.add(const Duration(hours: 1)),
        [10],
      );
      expect(result[10]!.length, 1);
      expect(result[10]!.first.id, 1);
    });
  });
}
