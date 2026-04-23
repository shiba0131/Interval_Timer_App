import 'dart:convert';

import '../local/pinpon_database.dart';

class MatchRecord {
  const MatchRecord({
    this.id,
    this.matchDate,
    this.tournamentName = '',
    required this.opponentName,
    this.opponentTeam = '',
    this.playStyle = '未選択',
    this.foreRubber = '未選択',
    this.backRubber = '未選択',
    this.dominantHand = '未選択',
    this.racketGrip = '未選択',
    this.gameCount = 5,
    this.mySetCount = 0,
    this.oppSetCount = 0,
    this.scores = const [],
    this.winLossReason = '',
    this.issueTags = const [],
    this.createdAt,
  });

  final int? id;
  final String? matchDate;
  final String tournamentName;
  final String opponentName;
  final String opponentTeam;
  final String playStyle;
  final String foreRubber;
  final String backRubber;
  final String dominantHand;
  final String racketGrip;
  final int gameCount;
  final int mySetCount;
  final int oppSetCount;
  final List<ScoreEntry> scores;
  final String winLossReason;
  final List<String> issueTags;
  final String? createdAt;

  factory MatchRecord.fromMap(Map<String, Object?> map) {
    return MatchRecord(
      id: map['id'] as int?,
      matchDate: map['match_date'] as String?,
      tournamentName: (map['tournament_name'] as String?) ?? '',
      opponentName: (map['opponent_name'] as String?) ?? '',
      opponentTeam: (map['opponent_team'] as String?) ?? '',
      playStyle: (map['play_style'] as String?) ?? '未選択',
      foreRubber: (map['fore_rubber'] as String?) ?? '未選択',
      backRubber: (map['back_rubber'] as String?) ?? '未選択',
      dominantHand: (map['dominant_hand'] as String?) ?? '未選択',
      racketGrip: ((map['racket_grip'] as String?) ?? '').isEmpty
          ? 'シェーク'
          : (map['racket_grip'] as String?) ?? 'シェーク',
      gameCount: (map['game_count'] as int?) ?? 5,
      mySetCount: (map['my_set_count'] as int?) ?? 0,
      oppSetCount: (map['opp_set_count'] as int?) ?? 0,
      scores: _decodeScores(map['scores'] as String?),
      winLossReason: (map['win_loss_reason'] as String?) ?? '',
      issueTags: PinponDatabase.decodeJsonStringList(
        map['issue_tags'] as String?,
      ),
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'match_date': matchDate,
      'tournament_name': tournamentName,
      'opponent_name': opponentName,
      'opponent_team': opponentTeam,
      'play_style': playStyle,
      'fore_rubber': foreRubber,
      'back_rubber': backRubber,
      'dominant_hand': dominantHand,
      'racket_grip': racketGrip,
      'game_count': gameCount,
      'my_set_count': mySetCount,
      'opp_set_count': oppSetCount,
      'scores': jsonEncode(scores.map((score) => score.toJson()).toList()),
      'win_loss_reason': winLossReason,
      'issue_tags': jsonEncode(issueTags),
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  static List<ScoreEntry> _decodeScores(String? rawScores) {
    if (rawScores == null || rawScores.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawScores);
      if (decoded is List) {
        return decoded
            .whereType<List>()
            .where((entry) => entry.length == 2)
            .map(
              (entry) => ScoreEntry(
                myScore: int.tryParse(entry[0].toString()) ?? 0,
                oppScore: int.tryParse(entry[1].toString()) ?? 0,
              ),
            )
            .toList(growable: false);
      }
    } catch (_) {
      return const [];
    }

    return const [];
  }

  bool get isWin => mySetCount > oppSetCount;

  bool get isLoss => mySetCount < oppSetCount;

  String get resultLabel {
    if (isWin) {
      return '勝ち';
    }
    if (isLoss) {
      return '負け';
    }
    return '未決着';
  }

  String get matchDateText => (matchDate == null || matchDate!.trim().isEmpty)
      ? '日付未設定'
      : matchDate!;

  String get tournamentNameOrFallback =>
      tournamentName.trim().isEmpty ? 'なし' : tournamentName;

  String get opponentTeamOrFallback =>
      opponentTeam.trim().isEmpty ? 'なし' : opponentTeam;

  String get issueTagsText =>
      issueTags.isEmpty ? 'なし' : issueTags.join('、');

  List<String> get displayScores => scores
      .asMap()
      .entries
      .where((entry) => !(entry.value.myScore == 0 && entry.value.oppScore == 0))
      .map(
        (entry) =>
            '第${entry.key + 1}ゲーム: ${entry.value.myScore} - ${entry.value.oppScore}',
      )
      .toList(growable: false);
}

class ScoreEntry {
  const ScoreEntry({
    required this.myScore,
    required this.oppScore,
  });

  final int myScore;
  final int oppScore;

  List<int> toJson() => [myScore, oppScore];
}
