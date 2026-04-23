import 'dart:math';

import '../../data/models/match_record.dart';
import '../../data/repositories/pinpon_repository.dart';

class TestDataService {
  TestDataService({required PinponRepository repository})
      : _repository = repository;

  final PinponRepository _repository;
  final Random _random = Random(42);

  static const _fixedOpponentName = '佐藤 健太';
  static const _fixedOpponentTeam = '南台クラブ';

  static const _styles = <String>[
    'ドライブ主戦',
    '前陣速攻',
    'カットマン',
    '異質攻守',
  ];

  static const _hands = <String>[
    '右利き',
    '左利き',
  ];

  static const _grips = <String>[
    'シェーク',
    'ペン',
  ];

  static const _rubbers = <String>[
    '裏ソフト',
    '表ソフト',
    '粒高',
    'アンチ',
    '一枚',
  ];

  static const _tournaments = <String>[
    '市民卓球大会',
    '春季リーグ',
    '練習試合',
    '月例会',
    'クラブ対抗戦',
    'ナイターリーグ',
  ];

  static const _names = <String>[
    '高橋 拓海',
    '鈴木 悠斗',
    '田中 颯真',
    '伊藤 海翔',
    '渡辺 大輝',
    '山本 蓮',
    '中村 陽向',
    '小林 湊',
    '加藤 蒼',
    '吉田 陸',
    '山田 結翔',
    '佐々木 晴',
    '松本 湧斗',
    '井上 朝陽',
    '木村 新',
    '林 颯太',
    '清水 光',
    '斎藤 直樹',
    '阿部 翔',
    '橋本 凛',
    '池田 航',
    '森 大和',
    '石川 拓真',
    '前田 優真',
    '岡田 陽太',
    '長谷川 創',
    '藤田 慎',
    '後藤 遥斗',
    '村上 叶',
    '近藤 陽介',
    '坂本 大翔',
    '遠藤 岳',
    '青木 悠真',
  ];

  static const _teams = <String>[
    '中央クラブ',
    '青葉クラブ',
    '北斗会',
    '緑台卓球',
    '東山TC',
    'みなと卓友会',
    '光ヶ丘クラブ',
  ];

  static const _tags = <String>[
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

  Future<void> insertSampleMatches({
    int totalCount = 50,
    int fixedOpponentCount = 17,
  }) async {
    final matches = <MatchRecord>[];
    final today = DateTime.now();

    for (var i = 0; i < totalCount; i++) {
      final usesFixedOpponent = i < fixedOpponentCount;
      final style = _pick(_styles);
      final gameCount = _pick(const [3, 5, 7]);
      final myWins = _random.nextDouble() < 0.56;
      final scores = _buildScores(gameCount, myWins);
      final mySetCount =
          scores.where((score) => score.myScore > score.oppScore).length;
      final oppSetCount =
          scores.where((score) => score.oppScore > score.myScore).length;
      final tagSelection = _buildTags(style, myWins, usesFixedOpponent);
      final daysAgo = (i * 3) + _random.nextInt(9);
      final matchDate = today.subtract(Duration(days: daysAgo));

      final opponentName =
          usesFixedOpponent ? _fixedOpponentName : _names[(i - fixedOpponentCount) % _names.length];
      final opponentTeam =
          usesFixedOpponent ? _fixedOpponentTeam : _pick(_teams);

      matches.add(
        MatchRecord(
          matchDate: _formatDate(matchDate),
          tournamentName: _pick(_tournaments),
          opponentName: opponentName,
          opponentTeam: opponentTeam,
          playStyle: style,
          foreRubber: _pick(_rubbers),
          backRubber: _pick(_rubbers),
          dominantHand: _pick(_hands),
          racketGrip: _pick(_grips),
          gameCount: gameCount,
          mySetCount: mySetCount,
          oppSetCount: oppSetCount,
          scores: scores,
          winLossReason: _buildMemo(
            opponentName: opponentName,
            style: style,
            tags: tagSelection,
            isWin: myWins,
          ),
          issueTags: tagSelection,
          createdAt: matchDate
              .add(Duration(hours: 19 + (i % 3), minutes: (i * 7) % 60))
              .toIso8601String(),
        ),
      );
    }

    await _repository.saveMatches(matches);
  }

  T _pick<T>(List<T> values) => values[_random.nextInt(values.length)];

  List<ScoreEntry> _buildScores(int gameCount, bool myWins) {
    final neededSets = (gameCount ~/ 2) + 1;
    final totalPlayed = neededSets + _random.nextInt(gameCount - neededSets + 1);
    var mySets = 0;
    var oppSets = 0;
    final scores = <ScoreEntry>[];

    for (var i = 0; i < totalPlayed; i++) {
      final mustWin = myWins
          ? mySets < neededSets && (oppSets >= neededSets - 1 || i == totalPlayed - 1)
          : oppSets < neededSets && (mySets >= neededSets - 1 || i == totalPlayed - 1);

      final currentMyWin =
          mustWin ? myWins : _random.nextDouble() < (myWins ? 0.58 : 0.42);

      if (currentMyWin && mySets < neededSets) {
        mySets += 1;
        scores.add(_winningScore(mySide: true));
      } else if (!currentMyWin && oppSets < neededSets) {
        oppSets += 1;
        scores.add(_winningScore(mySide: false));
      } else if (mySets < neededSets) {
        mySets += 1;
        scores.add(_winningScore(mySide: true));
      } else {
        oppSets += 1;
        scores.add(_winningScore(mySide: false));
      }

      if (mySets == neededSets || oppSets == neededSets) {
        break;
      }
    }

    while (scores.length < gameCount) {
      scores.add(const ScoreEntry(myScore: 0, oppScore: 0));
    }

    return scores;
  }

  ScoreEntry _winningScore({required bool mySide}) {
    final deuce = _random.nextDouble() < 0.22;
    if (deuce) {
      final loser = 10 + _random.nextInt(4);
      final winner = loser + 2;
      return mySide
          ? ScoreEntry(myScore: winner, oppScore: loser)
          : ScoreEntry(myScore: loser, oppScore: winner);
    }

    final loser = _random.nextInt(10);
    return mySide
        ? ScoreEntry(myScore: 11, oppScore: loser)
        : ScoreEntry(myScore: loser, oppScore: 11);
  }

  List<String> _buildTags(String style, bool isWin, bool fixedOpponent) {
    final base = <String>{
      if (fixedOpponent) 'レシーブミス',
      if (fixedOpponent) '戦術ミス',
      if (style == 'カットマン') 'ドライブミス',
      if (style == '前陣速攻') 'ブロックミス',
      if (!isWin) 'メンタル',
    };

    final count = 1 + _random.nextInt(3);
    while (base.length < count) {
      base.add(_pick(_tags));
    }
    return base.toList(growable: false);
  }

  String _buildMemo({
    required String opponentName,
    required String style,
    required List<String> tags,
    required bool isWin,
  }) {
    if (isWin) {
      return '$opponentName 戦は $style 対策が機能。特に ${tags.first} を意識して修正できた。';
    }
    return '$opponentName 戦は ${tags.join("、")} が課題。$style 相手への組み立てを見直したい。';
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
