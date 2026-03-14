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
      debugPrint('EPG: Downloaded ${(gzippedData.length / 1024 / 1024).toStringAsFixed(1)} MB, parsing...');

      final result = await parseXmltvInIsolate(gzippedData);
      debugPrint('EPG: Parsed ${result.channels.length} channels, ${result.programs.length} programs');

      await _db.clearAllPrograms();
      await _db.upsertChannels(result.channels);
      await _db.upsertPrograms(result.programs);
      await _db.setLastUpdated(DateTime.now());
      await _db.clearOldPrograms();

      debugPrint('EPG: Database updated successfully');
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

  Future<DateTime?> getLastUpdated() => _db.getLastUpdated();

  Future<void> dispose() async {
    _refreshTimer?.cancel();
    await _db.close();
  }
}
