import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models/channel.dart';

class PlaylistDatabase {
  static const _dbName = 'megav_playlist.db';
  static const _version = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE channels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            url TEXT NOT NULL,
            logo_url TEXT,
            group_title TEXT,
            tvg_id TEXT,
            tvg_name TEXT,
            language TEXT
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_channels_group ON channels (group_title)
        ''');

        await db.execute('''
          CREATE TABLE groups_cache (
            name TEXT PRIMARY KEY,
            channel_count INTEGER NOT NULL,
            sort_order INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE playlist_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  Future<void> replaceAllChannels(List<Channel> channels) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('channels');
      await txn.delete('groups_cache');

      final groupCounts = <String, int>{};

      for (var i = 0; i < channels.length; i += 500) {
        final end = (i + 500).clamp(0, channels.length);
        final batch = txn.batch();
        for (var j = i; j < end; j++) {
          final ch = channels[j];
          batch.insert('channels', {
            'name': ch.name,
            'url': ch.url,
            'logo_url': ch.logoUrl,
            'group_title': ch.groupTitle,
            'tvg_id': ch.tvgId,
            'tvg_name': ch.tvgName,
            'language': ch.language,
          });
          final g = ch.groupTitle ?? 'Uncategorized';
          groupCounts[g] = (groupCounts[g] ?? 0) + 1;
        }
        await batch.commit(noResult: true);
      }

      // Pre-compute groups_cache for fast group listing
      final gBatch = txn.batch();
      var order = 0;
      final sorted = groupCounts.keys.toList()..sort();
      for (final name in sorted) {
        gBatch.insert('groups_cache', {'name': name, 'channel_count': groupCounts[name], 'sort_order': order++});
      }
      await gBatch.commit(noResult: true);
    });
  }

  // ---------------------------------------------------------------------------
  // Read — Groups
  // ---------------------------------------------------------------------------

  Future<List<({String name, int count})>> getGroups() async {
    final db = await database;
    final rows = await db.query('groups_cache', orderBy: 'sort_order ASC');
    return rows.map((r) => (name: r['name'] as String, count: r['channel_count'] as int)).toList();
  }

  Future<int> getGroupCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM groups_cache');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Read — Channels (paginated)
  // ---------------------------------------------------------------------------

  Future<List<Channel>> getChannelsByGroup(String groupName, {int limit = 20, int offset = 0}) async {
    final db = await database;
    final rows = await db.query(
      'channels',
      where: 'group_title = ?',
      whereArgs: [groupName],
      limit: limit,
      offset: offset,
      orderBy: 'id ASC',
    );
    return rows.map(_channelFromRow).toList();
  }

  Future<int> getChannelCountInGroup(String groupName) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM channels WHERE group_title = ?', [groupName]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Channel>> getFeaturedChannels({int limit = 8}) async {
    final db = await database;
    final rows = await db.query('channels', limit: limit, orderBy: 'id ASC');
    return rows.map(_channelFromRow).toList();
  }

  Future<int> getTotalChannelCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM channels');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Channel?> getChannelByIndex(int index) async {
    final db = await database;
    final rows = await db.query('channels', limit: 1, offset: index, orderBy: 'id ASC');
    if (rows.isEmpty) return null;
    return _channelFromRow(rows.first);
  }

  Future<int> getGlobalIndex(Channel channel) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM channels WHERE id < (SELECT id FROM channels WHERE url = ? LIMIT 1)',
      [channel.url],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Search channels by name.
  Future<List<Channel>> searchChannels(String query, {int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'channels',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      limit: limit,
      orderBy: 'name ASC',
    );
    return rows.map(_channelFromRow).toList();
  }

  // ---------------------------------------------------------------------------
  // Meta
  // ---------------------------------------------------------------------------

  Future<String?> getPlaylistUrl() async {
    final db = await database;
    final rows = await db.query('playlist_meta', where: "key = 'url'");
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setPlaylistUrl(String url) async {
    final db = await database;
    await db.insert('playlist_meta', {'key': 'url', 'value': url}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DateTime?> getLastUpdated() async {
    final db = await database;
    final rows = await db.query('playlist_meta', where: "key = 'last_updated'");
    if (rows.isEmpty) return null;
    final ms = int.tryParse(rows.first['value'] as String);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastUpdated(DateTime time) async {
    final db = await database;
    await db.insert('playlist_meta', {
      'key': 'last_updated',
      'value': '${time.millisecondsSinceEpoch}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Channel _channelFromRow(Map<String, Object?> row) {
    return Channel(
      name: row['name'] as String,
      url: row['url'] as String,
      logoUrl: row['logo_url'] as String?,
      groupTitle: row['group_title'] as String?,
      tvgId: row['tvg_id'] as String?,
      tvgName: row['tvg_name'] as String?,
      language: row['language'] as String?,
    );
  }
}
