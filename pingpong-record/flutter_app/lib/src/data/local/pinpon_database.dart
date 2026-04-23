import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class PinponDatabase {
  PinponDatabase._();

  static final PinponDatabase instance = PinponDatabase._();

  static const dbFileName = 'pinpon.db';
  static const matchesTable = 'matches';
  static const tagDefinitionsTable = 'tag_definitions';
  static const formDraftsTable = 'form_drafts';

  static const defaultTagOptions = <String>[
    'サーブミス',
    'レシーブミス',
    '3球目攻撃ミス',
    'ツッツキミス',
    'スピード不足',
    'ドライブミス',
    'ブロックミス',
    'フットワーク',
    'メンタル',
    '戦術ミス',
    'スタミナ切れ',
  ];

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, dbFileName);
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await _createSchema(database);
        await _seedDefaultTags(database);
      },
      onOpen: (database) async {
        await _ensureCompatibility(database);
      },
    );

    _database = db;
    return db;
  }

  Future<String> get databasePath async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, dbFileName);
  }

  Future<void> close() async {
    final existing = _database;
    if (existing != null) {
      await existing.close();
      _database = null;
    }
  }

  Future<void> reopen() async {
    await close();
    await database;
  }

  Future<void> _createSchema(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $matchesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        match_date TEXT,
        tournament_name TEXT,
        opponent_name TEXT,
        opponent_team TEXT,
        play_style TEXT,
        fore_rubber TEXT,
        back_rubber TEXT,
        dominant_hand TEXT,
        racket_grip TEXT,
        game_count INTEGER,
        my_set_count INTEGER,
        opp_set_count INTEGER,
        scores TEXT,
        win_loss_reason TEXT,
        issue_tags TEXT,
        created_at TEXT
      )
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS $tagDefinitionsTable (
        tag_name TEXT PRIMARY KEY,
        is_hidden INTEGER DEFAULT 0,
        sort_order INTEGER,
        created_at TEXT
      )
    ''');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS $formDraftsTable (
        draft_key TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureCompatibility(Database database) async {
    await _createSchema(database);

    final columns = await database.rawQuery('PRAGMA table_info($matchesTable)');
    final existingColumns = {
      for (final row in columns) (row['name'] as String?) ?? '',
    };

    final alterStatements = <String, String>{
      'opponent_team': 'ALTER TABLE $matchesTable ADD COLUMN opponent_team TEXT',
      'fore_rubber': 'ALTER TABLE $matchesTable ADD COLUMN fore_rubber TEXT',
      'back_rubber': 'ALTER TABLE $matchesTable ADD COLUMN back_rubber TEXT',
      'racket_grip': 'ALTER TABLE $matchesTable ADD COLUMN racket_grip TEXT',
      'game_count': 'ALTER TABLE $matchesTable ADD COLUMN game_count INTEGER',
    };

    for (final entry in alterStatements.entries) {
      if (!existingColumns.contains(entry.key)) {
        await database.execute(entry.value);
      }
    }

    await database.execute(
      '''
      UPDATE $matchesTable
      SET racket_grip = 'シェーク'
      WHERE racket_grip IS NULL OR racket_grip = ''
      ''',
    );

    await _seedDefaultTags(database);
    await _syncTagsFromMatches(database);
  }

  Future<void> _seedDefaultTags(Database database) async {
    final countResult = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM $tagDefinitionsTable',
    );
    final count = (countResult.first['count'] as int?) ?? 0;
    if (count > 0) {
      return;
    }

    final nowText = DateTime.now().toIso8601String();
    final batch = database.batch();
    for (var index = 0; index < defaultTagOptions.length; index++) {
      batch.insert(tagDefinitionsTable, {
        'tag_name': defaultTagOptions[index],
        'is_hidden': 0,
        'sort_order': index,
        'created_at': nowText,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _syncTagsFromMatches(Database database) async {
    final existingRows = await database.query(
      tagDefinitionsTable,
      columns: ['tag_name', 'sort_order'],
    );
    final existingTags = {
      for (final row in existingRows) (row['tag_name'] as String?) ?? '',
    }..remove('');

    var nextSort = existingRows
        .map((row) => row['sort_order'] as int? ?? -1)
        .fold<int>(-1, (max, value) => value > max ? value : max) +
        1;

    final matchRows = await database.query(
      matchesTable,
      columns: ['issue_tags'],
    );

    final batch = database.batch();
    for (final row in matchRows) {
      final rawTags = row['issue_tags'] as String?;
      for (final tag in decodeJsonStringList(rawTags)) {
        if (!existingTags.contains(tag)) {
          existingTags.add(tag);
          batch.insert(tagDefinitionsTable, {
            'tag_name': tag,
            'is_hidden': 0,
            'sort_order': nextSort,
            'created_at': DateTime.now().toIso8601String(),
          });
          nextSort += 1;
        }
      }
    }
    await batch.commit(noResult: true);
  }

  static List<String> decodeJsonStringList(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      return const [];
    }

    return const [];
  }
}
