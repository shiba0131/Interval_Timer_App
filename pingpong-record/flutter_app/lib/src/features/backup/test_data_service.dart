import 'dart:math';

import '../../data/models/match_record.dart';
import '../../data/repositories/pinpon_repository.dart';

/// 固定対戦相手の属性
class _Opponent {
  const _Opponent({
    required this.name,
    required this.team,
    required this.style,
    required this.hand,
    required this.grip,
    required this.fore,
    required this.back,
    required this.winRate,
    required this.mainTags,
    required this.winNote,
    required this.lossNote,
  });

  final String name;
  final String team;
  final String style;
  final String hand;
  final String grip;
  final String fore;
  final String back;

  /// 自分の勝率（0.0〜1.0）
  final double winRate;

  /// この相手に特有の課題タグ
  final List<String> mainTags;

  /// 勝ったときのメモテンプレート（{name} を置換）
  final String winNote;

  /// 負けたときのメモテンプレート（{name} を置換）
  final String lossNote;
}

class TestDataService {
  TestDataService({required PinponRepository repository})
      : _repository = repository;

  final PinponRepository _repository;
  final Random _random = Random(42);

  // ─── 固定10人の対戦相手 ───────────────────────────────────────────────────────
  static final _opponents = <_Opponent>[
    _Opponent(
      name: '佐藤 健太',
      team: '南台クラブ',
      style: 'ドライブ主戦',
      hand: '右利き',
      grip: 'シェーク',
      fore: '裏ソフト',
      back: '裏ソフト',
      winRate: 0.55,
      mainTags: ['レシーブミス', '戦術ミス', '3球目攻撃ミス'],
      winNote:
          '{name} 戦は相手のドライブに慣れてきた。早めのカウンターを意識したのが功を奏した。',
      lossNote:
          '{name} 戦は相手の両ハンドドライブに押し込まれた。フォア側への対応と戦術の組み立てを見直す必要がある。',
    ),
    _Opponent(
      name: '鈴木 悠斗',
      team: '青葉クラブ',
      style: '前陣速攻',
      hand: '右利き',
      grip: 'ペン',
      fore: '裏ソフト',
      back: '一枚',
      winRate: 0.40,
      mainTags: ['ブロックミス', 'スピード不足', 'レシーブミス'],
      winNote:
          '{name} 戦は相手の速攻に対してブロックが安定した。ミドルへの突き球が効いた。',
      lossNote:
          '{name} 戦はスピードについていけず。ブロックが浮いて連続攻撃を受けた。フォアブロックの精度向上が急務。',
    ),
    _Opponent(
      name: '田中 颯真',
      team: '北斗会',
      style: 'カットマン',
      hand: '右利き',
      grip: 'シェーク',
      fore: '裏ソフト',
      back: '粒高',
      winRate: 0.35,
      mainTags: ['ドライブミス', 'スタミナ切れ', 'フットワーク'],
      winNote:
          '{name} 戦は粒高対策を徹底。浮いたカットを確実に打ち抜いた。ラリーを短くする戦術が当たった。',
      lossNote:
          '{name} 戦は粒高バックにドライブが落ちて自滅。長いラリーでスタミナを削られた。安定したドライブと体力強化が課題。',
    ),
    _Opponent(
      name: '伊藤 海翔',
      team: '東山TC',
      style: '異質攻守',
      hand: '右利き',
      grip: 'シェーク',
      fore: '裏ソフト',
      back: '表ソフト',
      winRate: 0.45,
      mainTags: ['サーブミス', 'プッシュミス', '戦術ミス'],
      winNote:
          '{name} 戦は表ソフトのナックルに慣れてきた。回転量を見極めてミスを減らせた試合。',
      lossNote:
          '{name} 戦は表ソフトからのプッシュに翻弄された。サーブ選択も裏目に出てしまった。異質対策の練習が必要。',
    ),
    _Opponent(
      name: '渡辺 大輝',
      team: 'みなと卓友会',
      style: 'ドライブ主戦',
      hand: '左利き',
      grip: 'シェーク',
      fore: '裏ソフト',
      back: '裏ソフト',
      winRate: 0.50,
      mainTags: ['フォアカットミス', 'スマッシュミス', 'メンタル'],
      winNote:
          '{name} 戦は左利きのフォアドライブのコースを読めた。バック側へのサーブが効果的だった。',
      lossNote:
          '{name} 戦は左利き特有のフォアクロスに振り回された。メンタル的に崩れた場面が多く悔しい敗戦。',
    ),
    _Opponent(
      name: '山本 蓮',
      team: '緑台卓球',
      style: 'ドライブ主戦',
      hand: '右利き',
      grip: 'シェーク',
      fore: '裏ソフト',
      back: '裏ソフト',
      winRate: 0.65,
      mainTags: ['ツッツキミス', '3球目攻撃ミス'],
      winNote:
          '{name} 戦はバック側への長いサーブからの3球目が決まった。課題のツッツキも改善できた一戦。',
      lossNote:
          '{name} 戦はツッツキが浮いて3球目を打ち抜かれた。サーブ選択に迷いが出た。',
    ),
    _Opponent(
      name: '中村 陽向',
      team: '光ヶ丘クラブ',
      style: '前陣速攻',
      hand: '左利き',
      grip: 'ペン',
      fore: '表ソフト',
      back: '一枚',
      winRate: 0.30,
      mainTags: ['ブロックミス', 'スピード不足', 'レシーブミス', 'メンタル'],
      winNote:
          '{name} 戦は珍しく相手のミスに助けられた。ブロックをコースに打ち分けて主導権を握れた。',
      lossNote:
          '{name} 戦はスピードに完全についていけなかった。左ペンの表ソフトナックルが対処できない。根本的な対策が必要。',
    ),
    _Opponent(
      name: '小林 湊',
      team: '中央クラブ',
      style: 'カットマン',
      hand: '右利き',
      grip: 'シェーク',
      fore: '裏ソフト',
      back: 'アンチ',
      winRate: 0.60,
      mainTags: ['ドライブミス', 'フットワーク'],
      winNote:
          '{name} 戦はアンチの無回転に早めに対応できた。フットワークを使って動かすことで相手のミスを誘えた。',
      lossNote:
          '{name} 戦はアンチラバーの変化に対するドライブが全部ネット。フットワークが追いつかない場面も多かった。',
    ),
    _Opponent(
      name: '加藤 蒼',
      team: '東山TC',
      style: 'ドライブ主戦',
      hand: '右利き',
      grip: 'シェーク',
      fore: '裏ソフト',
      back: '裏ソフト',
      winRate: 0.70,
      mainTags: ['サーブミス', '3球目攻撃ミス'],
      winNote:
          '{name} 戦はサーブで先手を取り続けた。3球目の精度が上がっていることを実感できた試合。',
      lossNote:
          '{name} 戦はサーブが読まれてレシーブ攻撃を連続で受けた。サーブのバリエーションを増やしたい。',
    ),
    _Opponent(
      name: '吉田 陸',
      team: '青葉クラブ',
      style: '異質攻守',
      hand: '右利き',
      grip: 'シェーク',
      fore: '粒高',
      back: '裏ソフト',
      winRate: 0.25,
      mainTags: ['フォアカットミス', 'スマッシュミス', 'バックカットミス', 'メンタル'],
      winNote:
          '{name} 戦は粒高フォアへの攻略法を掴んだ。バック側からの展開を徹底して相手の粒高を使わせなかった。',
      lossNote:
          '{name} 戦は粒高フォアのブロック変化に全く対応できなかった。フォア側のスマッシュが片っ端から返ってきた。',
    ),
  ];

  static const _tournaments = <String>[
    '市民卓球大会',
    '春季リーグ',
    '練習試合',
    '月例会',
    'クラブ対抗戦',
    'ナイターリーグ',
    '秋季オープン戦',
    '友好杯',
  ];

  /// テストデータを挿入する
  /// [matchesPerOpponent] 1人あたりの試合数（デフォルト5）
  Future<void> insertSampleMatches({
    int totalCount = 50,
    int fixedOpponentCount = 17,
  }) async {
    // 引数は互換のために残すが、実際は10人×5試合で生成
    await _insertFixed(matchesPerOpponent: 5);
  }

  Future<void> _insertFixed({int matchesPerOpponent = 5}) async {
    final matches = <MatchRecord>[];
    final today = DateTime.now();
    var dayOffset = 0;

    for (final opp in _opponents) {
      for (var matchIndex = 0; matchIndex < matchesPerOpponent; matchIndex++) {
        final isWin = _random.nextDouble() < opp.winRate;
        final gameCount = _pick(const [3, 5, 7]);
        final scores = _buildScores(gameCount, isWin);
        final mySetCount =
            scores.where((s) => s.myScore > s.oppScore).length;
        final oppSetCount =
            scores.where((s) => s.oppScore > s.myScore).length;

        // 試合日：新しい順に並ぶよう dayOffset を増やす
        dayOffset += 3 + _random.nextInt(7);
        final matchDate = today.subtract(Duration(days: dayOffset));

        // 課題タグ（相手固有のタグを軸に1〜2件追加）
        final tags = _buildTags(opp, isWin);

        matches.add(
          MatchRecord(
            matchDate: _formatDate(matchDate),
            tournamentName: _pick(_tournaments),
            opponentName: opp.name,
            opponentTeam: opp.team,
            playStyle: opp.style,
            foreRubber: opp.fore,
            backRubber: opp.back,
            dominantHand: opp.hand,
            racketGrip: opp.grip,
            gameCount: gameCount,
            mySetCount: mySetCount,
            oppSetCount: oppSetCount,
            scores: scores,
            winLossReason: isWin
                ? opp.winNote.replaceAll('{name}', opp.name)
                : opp.lossNote.replaceAll('{name}', opp.name),
            issueTags: tags,
            createdAt: matchDate
                .add(Duration(
                  hours: 19 + matchIndex % 3,
                  minutes: (matchIndex * 13) % 60,
                ))
                .toIso8601String(),
          ),
        );
      }
    }

    await _repository.saveMatches(matches);
  }

  // ─── ユーティリティ ────────────────────────────────────────────────────────

  T _pick<T>(List<T> values) => values[_random.nextInt(values.length)];

  List<String> _buildTags(_Opponent opp, bool isWin) {
    final base = <String>{...opp.mainTags.take(isWin ? 1 : 2)};
    final extras = 1 + _random.nextInt(2);
    while (base.length < opp.mainTags.length.clamp(1, 2) + extras) {
      base.add(_pick(opp.mainTags));
    }
    return base.toList(growable: false);
  }

  List<ScoreEntry> _buildScores(int gameCount, bool myWins) {
    final neededSets = (gameCount ~/ 2) + 1;
    final totalPlayed =
        neededSets + _random.nextInt(gameCount - neededSets + 1);
    var mySets = 0;
    var oppSets = 0;
    final scores = <ScoreEntry>[];

    for (var i = 0; i < totalPlayed; i++) {
      final mustWin = myWins
          ? mySets < neededSets &&
              (oppSets >= neededSets - 1 || i == totalPlayed - 1)
          : oppSets < neededSets &&
              (mySets >= neededSets - 1 || i == totalPlayed - 1);

      final currentMyWin = mustWin
          ? myWins
          : _random.nextDouble() < (myWins ? 0.58 : 0.42);

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

      if (mySets == neededSets || oppSets == neededSets) break;
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

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
