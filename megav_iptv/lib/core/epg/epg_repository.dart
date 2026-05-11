import 'dart:async';

import '../api/api_client.dart';
import '../playlist/models/epg_program.dart';

class _CacheEntry {
  _CacheEntry(this.data, this.timestamp);
  final Map<int, List<EpgProgram>> data;
  final DateTime timestamp;
}

class EpgRepository {
  EpgRepository(this._api);

  final ApiClient _api;
  final Map<String, _CacheEntry> _cache = {};
  final Map<int, Future<List<EpgProgram>>> _inFlight = {};
  static const Duration _ttl = Duration(seconds: 60);

  String _cacheKey(DateTime from, DateTime to, List<int> channelIds) {
    final sorted = [...channelIds]..sort();
    return '${from.millisecondsSinceEpoch}_${to.millisecondsSinceEpoch}_${sorted.join(",")}';
  }

  Future<Map<int, List<EpgProgram>>> programmesInWindow(DateTime from, DateTime to, List<int> channelIds) async {
    final key = _cacheKey(from, to, channelIds);
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _ttl) {
      return cached.data;
    }

    // Try batch endpoint via dynamic dispatch — graceful fallback to fan-out.
    Map<int, List<EpgProgram>> result = {};
    try {
      // ignore: avoid_dynamic_calls
      final dyn = _api as dynamic;
      result = await dyn.getEpgWindow(from, to, channelIds) as Map<int, List<EpgProgram>>;
    } on NoSuchMethodError {
      // Fan-out fallback with in-flight de-dup
      result = await _fanOut(from, to, channelIds);
    } catch (_) {
      result = await _fanOut(from, to, channelIds);
    }

    _cache[key] = _CacheEntry(result, DateTime.now());
    return result;
  }

  Future<Map<int, List<EpgProgram>>> _fanOut(DateTime from, DateTime to, List<int> channelIds) async {
    final futures = <int, Future<List<EpgProgram>>>{};
    for (final id in channelIds) {
      futures[id] = _inFlight[id] ??= _api
          .getUpcomingPrograms(id)
          .then(
            (list) {
              _inFlight.remove(id);
              return list;
            },
            onError: (Object _, StackTrace _) {
              _inFlight.remove(id);
              return const <EpgProgram>[];
            },
          );
    }

    final result = <int, List<EpgProgram>>{};
    for (final entry in futures.entries) {
      try {
        final list = await entry.value;
        result[entry.key] = list.where((p) => !p.end.isBefore(from) && !p.start.isAfter(to)).toList();
      } catch (_) {
        result[entry.key] = const [];
      }
    }
    return result;
  }
}
