import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../playlist/models/epg_program.dart';
import 'epg_database.dart';
import 'xmltv_parser.dart';

class EpgRepository {
  final EpgDatabase _db = EpgDatabase();
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  String sourceUrl = 'https://iptvx.one/epg/epg.xml.gz';
  static const _refreshInterval = Duration(hours: 6);
  static const _programChunkSize = 1000;

  void startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());
  }

  Future<void> refresh({bool force = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      if (!force) {
        final lastUpdated = await _db.getLastUpdated();
        if (lastUpdated != null) {
          final elapsed = DateTime.now().difference(lastUpdated);
          if (elapsed < _refreshInterval) {
            debugPrint('EPG: Skipping refresh, last update ${elapsed.inMinutes}m ago');
            return;
          }
        }
      }

      debugPrint('EPG: Downloading from $sourceUrl ...');
      final response = await http.get(Uri.parse(sourceUrl));
      if (response.statusCode != 200) {
        throw Exception('EPG download failed: ${response.statusCode}');
      }

      final gzippedData = Uint8List.fromList(response.bodyBytes);
      debugPrint(
        'EPG: Downloaded ${(gzippedData.length / 1024 / 1024).toStringAsFixed(1)} MB, '
        'parsing with streaming parser...',
      );

      final result = await parseXmltvInIsolate(gzippedData);
      debugPrint(
        'EPG: Parsed ${result.channels.length} channels, '
        '${result.programs.length} programs',
      );

      // Soft-delete workflow:
      // 1) Mark existing records as deleted
      await _db.markAllDeleted();

      // 2) Upsert channels (reactivates existing, inserts new)
      await _db.upsertChannels(result.channels);

      // 3) Insert programs in chunks of 1000 to avoid huge memory spikes
      for (var i = 0; i < result.programs.length; i += _programChunkSize) {
        final end = (i + _programChunkSize).clamp(0, result.programs.length);
        await _db.insertProgramsBatch(result.programs.sublist(i, end));
      }

      // 4) Purge orphaned records still marked as deleted
      await _db.purgeDeleted();

      // 5) Clean up programs older than 24h
      await _db.clearOldPrograms();

      await _db.setLastUpdated(DateTime.now());

      final counts = await _db.getCounts();
      debugPrint(
        'EPG: Database updated — ${counts.channels} channels, '
        '${counts.programs} programs',
      );
    } catch (e, st) {
      debugPrint('EPG: Refresh error: $e\n$st');
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<EpgProgram?> getCurrentProgram(String channelId) {
    return _db.getCurrentProgram(channelId);
  }

  Future<EpgProgram?> getNextProgram(String channelId) {
    return _db.getNextProgram(channelId);
  }

  Future<List<EpgProgram>> getProgramsForChannel(String channelId, {DateTime? from, DateTime? to}) {
    return _db.getProgramsForChannel(channelId, from: from, to: to);
  }

  Future<List<EpgProgram>> searchPrograms(String query, {int limit = 50}) {
    return _db.searchPrograms(query, limit: limit);
  }

  Future<DateTime?> getLastUpdated() => _db.getLastUpdated();

  Future<({int channels, int programs})> getCounts() => _db.getCounts();

  Future<void> dispose() async {
    _refreshTimer?.cancel();
    await _db.close();
  }
}
