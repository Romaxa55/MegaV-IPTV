import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../playlist/models/epg_channel.dart';
import '../playlist/models/epg_program.dart';

class EpgDatabase {
  static const _dbName = 'megav_epg.db';
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
          CREATE TABLE epg_channels (
            id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            icon TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE epg_programs (
            channel_id TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            category TEXT,
            icon TEXT,
            start INTEGER NOT NULL,
            end_time INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_programs_channel_start
          ON epg_programs (channel_id, start)
        ''');
        await db.execute('''
          CREATE TABLE epg_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> upsertChannels(List<EpgChannel> channels) async {
    final db = await database;
    final batch = db.batch();
    for (final ch in channels) {
      batch.insert('epg_channels', ch.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertPrograms(List<EpgProgram> programs) async {
    final db = await database;
    final batch = db.batch();
    for (final prog in programs) {
      batch.insert('epg_programs', prog.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearAllPrograms() async {
    final db = await database;
    await db.delete('epg_programs');
  }

  Future<void> clearOldPrograms() async {
    final db = await database;
    final yesterday = DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    await db.delete('epg_programs', where: 'end_time < ?', whereArgs: [yesterday]);
  }

  Future<EpgProgram?> getCurrentProgram(String channelId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'epg_programs',
      where: 'channel_id = ? AND start <= ? AND end_time > ?',
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
      where: 'channel_id = ? AND start > ?',
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
      where: 'channel_id = ? AND end_time > ? AND start < ?',
      whereArgs: [channelId, fromMs, toMs],
      orderBy: 'start ASC',
    );
    return rows.map(EpgProgram.fromMap).toList();
  }

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
