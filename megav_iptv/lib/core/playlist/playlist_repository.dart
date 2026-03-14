import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models/channel.dart';
import 'm3u_parser.dart';
import 'playlist_database.dart';

class PlaylistRepository {
  final PlaylistDatabase _db = PlaylistDatabase();
  bool _isLoading = false;

  PlaylistDatabase get database => _db;

  /// Load playlist from URL, parse, store in DB.
  /// Skips download if already loaded from the same URL (unless [force]).
  Future<void> loadPlaylist(String url, {bool force = false}) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      if (!force) {
        final savedUrl = await _db.getPlaylistUrl();
        final lastUpdated = await _db.getLastUpdated();
        if (savedUrl == url && lastUpdated != null) {
          final count = await _db.getTotalChannelCount();
          if (count > 0) {
            debugPrint('Playlist: Using cached DB ($count channels)');
            return;
          }
        }
      }

      debugPrint('Playlist: Downloading $url ...');
      final stopwatch = Stopwatch()..start();

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Playlist download failed: ${response.statusCode}');
      }

      debugPrint('Playlist: Downloaded in ${stopwatch.elapsedMilliseconds}ms, parsing...');
      stopwatch.reset();

      final parser = M3uParser();
      final channels = parser.parseChannels(response.body);

      debugPrint('Playlist: Parsed ${channels.length} channels in ${stopwatch.elapsedMilliseconds}ms, saving to DB...');
      stopwatch.reset();

      await _db.replaceAllChannels(channels);
      await _db.setPlaylistUrl(url);
      await _db.setLastUpdated(DateTime.now());

      debugPrint('Playlist: Saved to DB in ${stopwatch.elapsedMilliseconds}ms');
    } finally {
      _isLoading = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Delegated reads (lazy, paginated)
  // ---------------------------------------------------------------------------

  Future<List<({String name, int count})>> getGroups() => _db.getGroups();

  Future<int> getGroupCount() => _db.getGroupCount();

  Future<List<Channel>> getChannelsByGroup(String groupName, {int limit = 20, int offset = 0}) =>
      _db.getChannelsByGroup(groupName, limit: limit, offset: offset);

  Future<int> getChannelCountInGroup(String groupName) => _db.getChannelCountInGroup(groupName);

  Future<List<Channel>> getFeaturedChannels({int limit = 8}) => _db.getFeaturedChannels(limit: limit);

  Future<int> getTotalChannelCount() => _db.getTotalChannelCount();

  Future<Channel?> getChannelByIndex(int index) => _db.getChannelByIndex(index);

  Future<int> getGlobalIndex(Channel channel) => _db.getGlobalIndex(channel);

  Future<List<Channel>> searchChannels(String query, {int limit = 50}) => _db.searchChannels(query, limit: limit);

  Future<void> dispose() async {
    await _db.close();
  }
}
