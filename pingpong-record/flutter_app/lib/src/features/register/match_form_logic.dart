import '../../data/models/match_record.dart';

const playStyleOptions = <String>[
  '未選択',
  'ドライブ主戦',
  '前陣速攻',
  'カットマン',
  '異質攻守',
];

const dominantHandOptions = <String>[
  '未選択',
  '右利き',
  '左利き',
];

const racketGripOptions = <String>[
  '未選択',
  'シェーク',
  'ペン',
];

const rubberOptions = <String>[
  '未選択',
  '裏ソフト',
  '表ソフト',
  '粒高',
  'アンチ',
  '一枚',
];

const gameCountOptions = <int>[3, 5, 7];

Map<String, Object?> normalizeDraftPayload(Map<String, Object?> payload) {
  final normalized = Map<String, Object?>.from(payload);
  normalized['tags'] = normalizeIssueTags(_stringListValue(payload['tags']));
  return normalized;
}

List<String> normalizeIssueTags(List<String> tags) {
  const replacements = <String, String>{
    'ツッツキ浮き': 'ツッツキミス',
  };

  return tags
      .map((tag) => replacements[tag] ?? tag)
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

({int mySets, int oppSets}) calculateSetCount(List<ScoreEntry> scores) {
  var mySets = 0;
  var oppSets = 0;

  for (final score in scores) {
    if (score.myScore == 0 && score.oppScore == 0) {
      continue;
    }
    if (score.myScore >= 11 && (score.myScore - score.oppScore) >= 2) {
      mySets += 1;
    } else if (score.oppScore >= 11 && (score.oppScore - score.myScore) >= 2) {
      oppSets += 1;
    } else if (
        score.myScore > score.oppScore &&
        (score.myScore >= 11 || score.oppScore >= 11)) {
      mySets += 1;
    } else if (
        score.oppScore > score.myScore &&
        (score.myScore >= 11 || score.oppScore >= 11)) {
      oppSets += 1;
    }
  }

  return (mySets: mySets, oppSets: oppSets);
}

ScoreValidationResult validateScores(
  List<ScoreEntry> scores,
  int gameCount, {
  bool allowIncomplete = false,
}) {
  final errors = <String>[];
  final warnings = <String>[];
  final setCount = calculateSetCount(scores);
  final winningSetsNeeded = (gameCount ~/ 2) + 1;
  var playedGames = 0;

  for (var i = 0; i < scores.length; i++) {
    final score = scores[i];
    final gameNumber = i + 1;

    if (score.myScore == 0 && score.oppScore == 0) {
      continue;
    }

    playedGames += 1;
    final maxScore = score.myScore > score.oppScore ? score.myScore : score.oppScore;
    final minScore = score.myScore < score.oppScore ? score.myScore : score.oppScore;

    if (maxScore < 11) {
      final message = '第$gameNumberゲーム: 途中終了のスコアとして扱います。通常の試合結果としては未決着です。';
      if (allowIncomplete) {
        warnings.add(message);
      } else {
        errors.add('第$gameNumberゲーム: どちらかが11点以上に達している必要があります。');
      }
    } else if (maxScore == 11) {
      if (minScore >= 10) {
        errors.add('第$gameNumberゲーム: 10-10以降は2点差をつける必要があります。');
      }
    } else if ((score.myScore - score.oppScore).abs() != 2) {
      errors.add('第$gameNumberゲーム: 11点以降の決着は必ず2点差になります（例: 12-10, 14-12）。');
    }
  }

  if (errors.isEmpty) {
    if (setCount.mySets < winningSetsNeeded &&
        setCount.oppSets < winningSetsNeeded) {
      const message = '勝敗がつく前のスコアです。棄権や途中終了の記録として保存します。';
      if (allowIncomplete) {
        warnings.add(message);
      } else {
        errors.add('勝敗がつくまでスコアが入力されていません。');
      }
    } else if (playedGames > (setCount.mySets + setCount.oppSets)) {
      const message = '勝敗決定後の追加ゲームが入力されています。練習試合や参考スコアとして保存します。';
      if (allowIncomplete) {
        warnings.add(message);
      } else {
        errors.add('勝敗が決まった後の不要なゲームスコアが入力されています。');
      }
    }
  }

  return ScoreValidationResult(errors: errors, warnings: warnings);
}

DateTime parseDraftDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

int intValue(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool boolValue(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value == 1;
  }
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return fallback;
}

String stringValue(Object? value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  return fallback;
}

List<String> _stringListValue(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const [];
}

class ScoreValidationResult {
  const ScoreValidationResult({
    required this.errors,
    required this.warnings,
  });

  final List<String> errors;
  final List<String> warnings;
}
