import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../playlist/models/epg_channel.dart';
import '../playlist/models/epg_program.dart';

class EpgDatabase {
  static const _dbName = 'megav_epg.db';
  static const _version = 3;

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
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS epg_programs');
        await db.execute('DROP TABLE IF EXISTS epg_channels');
        await db.execute('DROP TABLE IF EXISTS epg_name_map');
        await db.execute('DROP TABLE IF EXISTS epg_meta');
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE epg_channels (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        icon TEXT,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE epg_programs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        channel_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT,
        icon TEXT,
        start INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_programs_channel_time
      ON epg_programs (channel_id, start, end_time)
    ''');

    await db.execute('''
      CREATE INDEX idx_programs_deleted
      ON epg_programs (deleted)
    ''');

    await db.execute('''
      CREATE TABLE epg_name_map (
        name_lower TEXT NOT NULL,
        channel_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_name_map_name
      ON epg_name_map (name_lower)
    ''');

    await db.execute('''
      CREATE TABLE epg_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // Soft-delete workflow (like Perfect Player):
  // 1. markAllDeleted() — before re-parse
  // 2. upsertChannels/insertPrograms — re-activates or inserts
  // 3. purgeDeleted() — remove orphans after successful parse
  // ---------------------------------------------------------------------------

  /// Mark all channels and programs as deleted before a re-parse.
  Future<void> markAllDeleted() async {
    final db = await database;
    await db.rawUpdate('UPDATE epg_channels SET deleted = 1');
    await db.rawUpdate('UPDATE epg_programs SET deleted = 1');
    await db.delete('epg_name_map');
  }

  /// Remove records still marked as deleted after a successful parse.
  Future<void> purgeDeleted() async {
    final db = await database;
    await db.delete('epg_programs', where: 'deleted = 1');
    await db.delete('epg_channels', where: 'deleted = 1');
  }

  /// Upsert channels — reactivates existing or inserts new.
  Future<void> upsertChannels(List<EpgChannel> channels) async {
    if (channels.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final ch in channels) {
      batch.rawInsert(
        '''INSERT OR REPLACE INTO epg_channels (id, display_name, icon, deleted)
           VALUES (?, ?, ?, 0)''',
        [ch.id, ch.displayName, ch.icon],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Insert display-name -> channel_id mappings (all alternate names).
  Future<void> insertNameMappings(Map<String, List<String>> channelIdToNames) async {
    if (channelIdToNames.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final entry in channelIdToNames.entries) {
      final channelId = entry.key;
      for (final name in entry.value) {
        batch.insert('epg_name_map', {'name_lower': name.toLowerCase().trim(), 'channel_id': channelId});
      }
    }
    await batch.commit(noResult: true);
  }

  /// Insert programs in a chunked batch. Marks them as not deleted.
  /// Call this multiple times with chunks of ~1000 programs.
  Future<void> insertProgramsBatch(List<EpgProgram> programs) async {
    if (programs.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final prog in programs) {
      batch.rawInsert(
        '''INSERT INTO epg_programs
           (channel_id, title, description, category, icon, start, end_time, deleted)
           VALUES (?, ?, ?, ?, ?, ?, ?, 0)''',
        [
          prog.channelId,
          prog.title,
          prog.description,
          prog.category,
          prog.icon,
          prog.start.millisecondsSinceEpoch,
          prog.end.millisecondsSinceEpoch,
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Legacy: insert all programs at once (wraps chunked version).
  Future<void> upsertPrograms(List<EpgProgram> programs) async {
    const chunkSize = 1000;
    for (var i = 0; i < programs.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, programs.length);
      await insertProgramsBatch(programs.sublist(i, end));
    }
  }

  Future<void> clearOldPrograms() async {
    final db = await database;
    final yesterday = DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    await db.delete('epg_programs', where: 'end_time < ?', whereArgs: [yesterday]);
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  Future<EpgProgram?> getCurrentProgram(String channelId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'epg_programs',
      where: 'channel_id = ? AND start <= ? AND end_time > ? AND deleted = 0',
      whereArgs: [channelId, now, now],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EpgProgram.fromMap(rows.first);
  }

  Future<EpgProgram?> getNextProgram(String channelId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'epg_programs',
      where: 'channel_id = ? AND start > ? AND deleted = 0',
      whereArgs: [channelId, now],
      orderBy: 'start ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EpgProgram.fromMap(rows.first);
  }

  Future<List<EpgProgram>> getProgramsForChannel(String channelId, {DateTime? from, DateTime? to}) async {
    final db = await database;
    final fromMs = (from ?? DateTime.now().subtract(const Duration(hours: 2))).millisecondsSinceEpoch;
    final toMs = (to ?? DateTime.now().add(const Duration(hours: 24))).millisecondsSinceEpoch;

    final rows = await db.query(
      'epg_programs',
      where: 'channel_id = ? AND end_time > ? AND start < ? AND deleted = 0',
      whereArgs: [channelId, fromMs, toMs],
      orderBy: 'start ASC',
    );
    return rows.map(EpgProgram.fromMap).toList();
  }

  /// Search programs by title across all channels.
  Future<List<EpgProgram>> searchPrograms(String query, {int limit = 50}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'epg_programs',
      where: 'title LIKE ? AND end_time > ? AND deleted = 0',
      whereArgs: ['%$query%', now],
      orderBy: 'start ASC',
      limit: limit,
    );
    return rows.map(EpgProgram.fromMap).toList();
  }

  /// Find EPG channel ID by display name (case-insensitive fuzzy match).
  /// Returns the best matching channel_id or null.
  Future<String?> findChannelIdByName(String channelName) async {
    final db = await database;
    final normalized = channelName.trim().toLowerCase();

    // Exact match first
    var rows = await db.query(
      'epg_channels',
      columns: ['id'],
      where: 'LOWER(display_name) = ? AND deleted = 0',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;

    // LIKE match (display_name contains the channel name)
    rows = await db.query(
      'epg_channels',
      columns: ['id'],
      where: 'LOWER(display_name) LIKE ? AND deleted = 0',
      whereArgs: ['%$normalized%'],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;

    return null;
  }

  /// Bulk-resolve channel names to EPG channel IDs.
  /// Uses epg_name_map which has ALL alternate display-names.
  Future<Map<String, String>> buildNameToIdMap() async {
    final db = await database;
    final rows = await db.query('epg_name_map');
    final map = <String, String>{};
    for (final row in rows) {
      final name = row['name_lower'] as String;
      final id = row['channel_id'] as String;
      map[name] = id;
    }
    return map;
  }

  /// Get channel info by ID.
  Future<EpgChannel?> getChannel(String channelId) async {
    final db = await database;
    final rows = await db.query('epg_channels', where: 'id = ? AND deleted = 0', whereArgs: [channelId], limit: 1);
    if (rows.isEmpty) return null;
    return EpgChannel.fromMap(rows.first);
  }

  /// Resolve a playlist channel to an EPG channel ID.
  /// Priority: tvgId exact → name_map exact → name_map LIKE.
  Future<String?> resolveChannelId({String? tvgId, String? channelName}) async {
    final db = await database;

    // 1. Try tvgId as direct EPG channel ID
    if (tvgId != null && tvgId.isNotEmpty) {
      final rows = await db.query(
        'epg_channels',
        columns: ['id'],
        where: 'id = ? AND deleted = 0',
        whereArgs: [tvgId],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first['id'] as String;
    }

    if (channelName == null || channelName.isEmpty) return null;
    final normalized = channelName.toLowerCase().trim();

    // 2. Exact match in epg_name_map (all alternate display names)
    var rows = await db.query(
      'epg_name_map',
      columns: ['channel_id'],
      where: 'name_lower = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['channel_id'] as String;

    // 3. Fuzzy LIKE match in epg_name_map
    rows = await db.query(
      'epg_name_map',
      columns: ['channel_id'],
      where: 'name_lower LIKE ?',
      whereArgs: ['%$normalized%'],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['channel_id'] as String;

    // 4. Reverse: check if channel name contains any EPG name
    rows = await db.rawQuery('SELECT channel_id FROM epg_name_map WHERE ? LIKE \'%\' || name_lower || \'%\' LIMIT 1', [
      normalized,
    ]);
    if (rows.isNotEmpty) return rows.first['channel_id'] as String;

    return null;
  }

  /// Get total counts for diagnostics.
  Future<({int channels, int programs})> getCounts() async {
    final db = await database;
    final chResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM epg_channels WHERE deleted = 0');
    final prResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM epg_programs WHERE deleted = 0');
    return (channels: Sqflite.firstIntValue(chResult) ?? 0, programs: Sqflite.firstIntValue(prResult) ?? 0);
  }

  // ---------------------------------------------------------------------------
  // Meta
  // ---------------------------------------------------------------------------

  Future<DateTime?> getLastUpdated() async {
    final db = await database;
    final rows = await db.query('epg_meta', where: "key = 'last_updated'");
    if (rows.isEmpty) return null;
    final ms = int.tryParse(rows.first['value'] as String);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setLastUpdated(DateTime time) async {
    final db = await database;
    await db.insert('epg_meta', {
      'key': 'last_updated',
      'value': '${time.millisecondsSinceEpoch}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
