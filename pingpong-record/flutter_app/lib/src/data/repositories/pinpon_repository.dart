import 'package:sqflite/sqflite.dart';

import '../local/pinpon_database.dart';
import '../models/form_draft.dart';
import '../models/match_record.dart';
import '../models/tag_definition.dart';

class PinponRepository {
  PinponRepository({PinponDatabase? database})
      : _database = database ?? PinponDatabase.instance;

  final PinponDatabase _database;

  Future<AppSnapshot> loadSnapshot() async {
    final db = await _database.database;
    final matchCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${PinponDatabase.matchesTable}',
          ),
        ) ??
        0;
    final tagCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${PinponDatabase.tagDefinitionsTable}',
          ),
        ) ??
        0;

    return AppSnapshot(
      databasePath: await _database.databasePath,
      matchCount: matchCount,
      tagCount: tagCount,
      tags: await loadTagDefinitions(),
    );
  }

  Future<List<MatchRecord>> loadMatches() async {
    final db = await _database.database;
    final rows = await db.query(
      PinponDatabase.matchesTable,
      orderBy: 'id DESC',
    );
    return rows.map(MatchRecord.fromMap).toList(growable: false);
  }

  Future<List<OpponentProfile>> loadOpponentProfiles() async {
    final db = await _database.database;
    final rows = await db.query(
      PinponDatabase.matchesTable,
      columns: [
        'opponent_name',
        'opponent_team',
        'play_style',
        'dominant_hand',
        'racket_grip',
        'fore_rubber',
        'back_rubber',
      ],
      where: "opponent_name IS NOT NULL AND opponent_name != ''",
      orderBy: 'match_date DESC, id DESC',
    );

    final profiles = <String, OpponentProfile>{};
    for (final row in rows) {
      final opponentName = (row['opponent_name'] as String?)?.trim() ?? '';
      if (opponentName.isEmpty || profiles.containsKey(opponentName)) {
        continue;
      }

      profiles[opponentName] = OpponentProfile(
        opponentName: opponentName,
        opponentTeam: (row['opponent_team'] as String?) ?? '',
        playStyle: (row['play_style'] as String?) ?? '未選択',
        dominantHand: (row['dominant_hand'] as String?) ?? '未選択',
        racketGrip: ((row['racket_grip'] as String?) ?? '').isEmpty
            ? 'シェーク'
            : (row['racket_grip'] as String?) ?? 'シェーク',
        foreRubber: (row['fore_rubber'] as String?) ?? '未選択',
        backRubber: (row['back_rubber'] as String?) ?? '未選択',
      );
    }

    return profiles.values.toList(growable: false);
  }

  Future<int> saveMatch(MatchRecord match) async {
    final db = await _database.database;
    final data = match.toMap()..remove('id');

    if (match.id == null) {
      return db.insert(PinponDatabase.matchesTable, data);
    }

    await db.update(
      PinponDatabase.matchesTable,
      data,
      where: 'id = ?',
      whereArgs: [match.id],
    );
    return match.id!;
  }

  Future<void> saveMatches(List<MatchRecord> matches) async {
    if (matches.isEmpty) {
      return;
    }

    final db = await _database.database;
    final batch = db.batch();
    for (final match in matches) {
      final data = match.toMap()..remove('id');
      if (match.id == null) {
        batch.insert(PinponDatabase.matchesTable, data);
      } else {
        batch.update(
          PinponDatabase.matchesTable,
          data,
          where: 'id = ?',
          whereArgs: [match.id],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteMatch(int id) async {
    final db = await _database.database;
    await db.delete(
      PinponDatabase.matchesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TagDefinition>> loadTagDefinitions({
    bool includeHidden = true,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      PinponDatabase.tagDefinitionsTable,
      where: includeHidden ? null : 'is_hidden = 0',
      orderBy: 'sort_order ASC, tag_name ASC',
    );
    return rows.map(TagDefinition.fromMap).toList(growable: false);
  }

  Future<void> saveDraft(FormDraft draft) async {
    final db = await _database.database;
    await db.insert(
      PinponDatabase.formDraftsTable,
      draft.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<FormDraft?> loadDraft(String draftKey) async {
    final db = await _database.database;
    final rows = await db.query(
      PinponDatabase.formDraftsTable,
      where: 'draft_key = ?',
      whereArgs: [draftKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }
    return FormDraft.fromMap(rows.first);
  }

  Future<void> deleteDraft(String draftKey) async {
    final db = await _database.database;
    await db.delete(
      PinponDatabase.formDraftsTable,
      where: 'draft_key = ?',
      whereArgs: [draftKey],
    );
  }
}

class OpponentProfile {
  const OpponentProfile({
    required this.opponentName,
    required this.opponentTeam,
    required this.playStyle,
    required this.dominantHand,
    required this.racketGrip,
    required this.foreRubber,
    required this.backRubber,
  });

  final String opponentName;
  final String opponentTeam;
  final String playStyle;
  final String dominantHand;
  final String racketGrip;
  final String foreRubber;
  final String backRubber;
}

class AppSnapshot {
  const AppSnapshot({
    required this.databasePath,
    required this.matchCount,
    required this.tagCount,
    required this.tags,
  });

  final String databasePath;
  final int matchCount;
  final int tagCount;
  final List<TagDefinition> tags;
}
