import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/match_record.dart';
import '../../data/repositories/pinpon_repository.dart';
import 'chart_widgets.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.repository,
    required this.refreshSignal,
  });

  final PinponRepository repository;
  final ValueListenable<int> refreshSignal;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  static const _tagLimitOptions = <int>[5, 10, 20, 50, 100, 9999];

  late Future<List<MatchRecord>> _matchesFuture;
  int _selectedTagLimit = 10;
  String? _selectedOpponentName;

  @override
  void initState() {
    super.initState();
    _matchesFuture = widget.repository.loadMatches();
    widget.refreshSignal.addListener(_handleExternalRefresh);
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_handleExternalRefresh);
    super.dispose();
  }

  void _handleExternalRefresh() {
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _matchesFuture = widget.repository.loadMatches();
    });
    await _matchesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<MatchRecord>>(
      future: _matchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('分析データの読み込みに失敗しました: ${snapshot.error}'),
            ),
          );
        }

        final matches = snapshot.data ?? const <MatchRecord>[];
        if (matches.isEmpty) {
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                SizedBox(height: 120),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('データがありません。試合結果を登録すると分析が表示されます。'),
                  ),
                ),
              ],
            ),
          );
        }

        final styleStats = _buildStyleStats(matches);
        final tagStats = _buildTagStats(matches, _selectedTagLimit);
        final recentOutcomes = _sortedMatches(matches, descending: false).takeLast(10);
        final monthlyStats = _buildMonthlyWinRates(matches);
        final monthlyTagTrends = _buildMonthlyTagTrends(matches);
        final opponentStats = _buildOpponentStats(matches);
        final selectedOpponent = _resolveSelectedOpponent(opponentStats);
        final overview = _buildOverview(matches, tagStats);

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionCard(
                title: 'サマリー',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricPill(label: '試合数', value: '${overview.totalMatches}'),
                    _MetricPill(label: '勝ち', value: '${overview.totalWins}'),
                    _MetricPill(label: '負け', value: '${overview.totalLosses}'),
                    _MetricPill(
                      label: '勝率',
                      value: '${overview.winRate.toStringAsFixed(1)}%',
                    ),
                    _MetricPill(
                      label: '最多タグ',
                      value: overview.topTagLabel,
                    ),
                    _MetricPill(
                      label: '最新試合',
                      value: overview.latestMatchLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '戦型別 勝率',
                child: styleStats.isEmpty
                    ? const Text('データ不足')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SimpleBarChart(
                            data: [
                              for (final stat in styleStats)
                                ChartBarDatum(
                                  label: stat.label,
                                  value: stat.winRate,
                                  valueLabel: '${stat.winRate.toStringAsFixed(1)}%',
                                ),
                            ],
                            maxValue: 100,
                          ),
                          const SizedBox(height: 16),
                          for (final stat in styleStats)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RatioBarTile(
                                label: stat.label,
                                valueText:
                                    '${stat.winRate.toStringAsFixed(1)}% (${stat.wins}/${stat.matches})',
                                ratio: stat.winRate / 100,
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '苦手戦型',
                child: styleStats.isEmpty
                    ? const Text('データ不足')
                    : Column(
                        children: [
                          for (final stat in styleStats)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SummaryRow(
                                title: stat.label,
                                subtitle:
                                    '試合数 ${stat.matches} / 勝ち ${stat.wins} / 負け ${stat.losses}',
                                trailing:
                                    '${stat.winRate.toStringAsFixed(1)}%',
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '課題タグ集計',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _selectedTagLimit,
                      decoration: const InputDecoration(
                        labelText: '集計対象の試合数',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final option in _tagLimitOptions)
                          DropdownMenuItem(
                            value: option,
                            child: Text(option == 9999 ? 'すべて' : '直近 $option 試合'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedTagLimit = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (tagStats.isEmpty)
                      Text(_selectedTagLimit == 9999
                          ? '全試合に課題タグの記録がありません。'
                          : '直近$_selectedTagLimit試合に課題タグの記録がありません。')
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SimpleBarChart(
                            data: [
                              for (final stat in tagStats.take(8))
                                ChartBarDatum(
                                  label: stat.label,
                                  value: stat.count.toDouble(),
                                  valueLabel: '${stat.count}回',
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          for (final stat in tagStats)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RatioBarTile(
                                label: stat.label,
                                valueText: '${stat.count}回',
                                ratio: stat.ratio,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '直近10試合の勝敗推移',
                child: recentOutcomes.isEmpty
                    ? const Text('データ不足')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SimpleLineChart(
                            labels: [
                              for (final match in recentOutcomes)
                                match.opponentName.isEmpty
                                    ? match.matchDateText
                                    : match.opponentName,
                            ],
                            series: [
                              ChartLineSeries(
                                name: '勝敗',
                                color: theme.colorScheme.primary,
                                points: [
                                  for (final match in recentOutcomes)
                                    switch (match.resultLabel) {
                                      '勝ち' => 1,
                                      '負け' => 0,
                                      _ => 0.5,
                                    },
                                ],
                              ),
                            ],
                            minValue: 0,
                            maxValue: 1,
                            height: 200,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '1 が勝ち、0 が負けです。',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          for (final match in recentOutcomes)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _OutcomeTimelineTile(match: match),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '月別勝率',
                child: monthlyStats.isEmpty
                    ? const Text('日付データ不足')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SimpleLineChart(
                            labels: [
                              for (final stat in monthlyStats) stat.label,
                            ],
                            series: [
                              ChartLineSeries(
                                name: '勝率',
                                color: theme.colorScheme.primary,
                                points: [
                                  for (final stat in monthlyStats) stat.winRate,
                                ],
                              ),
                            ],
                            minValue: 0,
                            maxValue: 100,
                            height: 210,
                          ),
                          const SizedBox(height: 16),
                          for (final stat in monthlyStats)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RatioBarTile(
                                label: stat.label,
                                valueText: '${stat.winRate.toStringAsFixed(1)}%',
                                ratio: stat.winRate / 100,
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '課題タグの月別推移',
                child: monthlyTagTrends.isEmpty
                    ? const Text('課題タグの時系列データがありません。')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '出現回数が多い上位5タグの月別推移です。',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          SimpleLineChart(
                            labels: [
                              for (final month in monthlyTagTrends.first.monthlyValues)
                                month.month,
                            ],
                            series: [
                              for (final trend in monthlyTagTrends)
                                ChartLineSeries(
                                  name: trend.tagName,
                                  color: _tagTrendColor(
                                    context,
                                    monthlyTagTrends.indexOf(trend),
                                  ),
                                  points: [
                                    for (final value in trend.monthlyValues)
                                      value.count.toDouble(),
                                  ],
                                ),
                            ],
                            minValue: 0,
                            maxValue: monthlyTagTrends
                                .map((trend) => trend.maxMonthlyCount.toDouble())
                                .fold<double>(1, (max, value) => value > max ? value : max),
                            height: 230,
                          ),
                          const SizedBox(height: 16),
                          for (final trend in monthlyTagTrends)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _MonthlyTagTrendCard(trend: trend),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: '対戦相手別 通算成績',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (opponentStats.isEmpty)
                      const Text('対戦相手データがありません。')
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedOpponent?.name,
                        decoration: const InputDecoration(
                          labelText: '詳細を見る対戦相手',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final stat in opponentStats)
                            DropdownMenuItem(
                              value: stat.name,
                              child: Text(stat.name),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedOpponentName = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      for (final stat in opponentStats.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SummaryRow(
                            title: stat.name,
                            subtitle:
                                '試合数 ${stat.matches} / 勝ち ${stat.wins} / 負け ${stat.losses} / 主な戦型 ${stat.mainStyle} / 最新日 ${stat.latestDate}',
                            trailing: '${stat.winRate.toStringAsFixed(1)}%',
                          ),
                        ),
                      if (selectedOpponent != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MetricPill(
                              label: '試合数',
                              value: '${selectedOpponent.matches}',
                            ),
                            _MetricPill(
                              label: '勝ち',
                              value: '${selectedOpponent.wins}',
                            ),
                            _MetricPill(
                              label: '負け',
                              value: '${selectedOpponent.losses}',
                            ),
                            _MetricPill(
                              label: '勝率',
                              value: '${selectedOpponent.winRate.toStringAsFixed(1)}%',
                            ),
                            _MetricPill(
                              label: '主な戦型',
                              value: selectedOpponent.mainStyle,
                            ),
                            _MetricPill(
                              label: '最新日',
                              value: selectedOpponent.latestDate,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '同じ相手との推移',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SimpleLineChart(
                          labels: [
                            for (final item in selectedOpponent.timeline)
                              item.label,
                          ],
                          series: [
                            ChartLineSeries(
                              name: '累計勝ち',
                              color: theme.colorScheme.primary,
                              points: [
                                for (final item in selectedOpponent.timeline)
                                  item.cumulativeWins.toDouble(),
                              ],
                            ),
                            ChartLineSeries(
                              name: '累計負け',
                              color: theme.colorScheme.error,
                              points: [
                                for (final item in selectedOpponent.timeline)
                                  item.cumulativeLosses.toDouble(),
                              ],
                            ),
                          ],
                          minValue: 0,
                          maxValue: mathMaxDouble([
                            for (final item in selectedOpponent.timeline)
                              item.cumulativeWins.toDouble(),
                            for (final item in selectedOpponent.timeline)
                              item.cumulativeLosses.toDouble(),
                          ], fallback: 1),
                          height: 220,
                        ),
                        const SizedBox(height: 16),
                        for (final item in selectedOpponent.timeline)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TimelineSummaryRow(item: item),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          '負けパターン',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (selectedOpponent.lossTagStats.isEmpty)
                          const Text('負け試合の課題タグ記録はありません。')
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SimpleBarChart(
                                data: [
                                  for (final stat in selectedOpponent.lossTagStats)
                                    ChartBarDatum(
                                      label: stat.label,
                                      value: stat.count.toDouble(),
                                      valueLabel: '${stat.count}回',
                                    ),
                                ],
                                height: 200,
                              ),
                              const SizedBox(height: 16),
                              for (final stat in selectedOpponent.lossTagStats)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _RatioBarTile(
                                    label: stat.label,
                                    valueText: '${stat.count}回',
                                    ratio: stat.ratio,
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        Text(
                          '敗戦メモ',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (selectedOpponent.lossNotes.isEmpty)
                          const Text('この相手にはまだ負けていません。')
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final note in selectedOpponent.lossNotes)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text('• $note'),
                                ),
                            ],
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<MatchRecord> _sortedMatches(
    List<MatchRecord> matches, {
    required bool descending,
  }) {
    final copy = [...matches];
    copy.sort((a, b) {
      final aDate = DateTime.tryParse(a.matchDate ?? '');
      final bDate = DateTime.tryParse(b.matchDate ?? '');
      final dateCompare = switch ((aDate, bDate)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        _ => aDate!.compareTo(bDate!),
      };
      final idCompare = (a.id ?? 0).compareTo(b.id ?? 0);
      final combined = dateCompare != 0 ? dateCompare : idCompare;
      return descending ? -combined : combined;
    });
    return copy;
  }

  List<_WinRateStat> _buildStyleStats(List<MatchRecord> matches) {
    final grouped = <String, List<MatchRecord>>{};
    for (final match in matches) {
      if (match.playStyle == '未選択') {
        continue;
      }
      grouped.putIfAbsent(match.playStyle, () => []).add(match);
    }

    final stats = grouped.entries.map((entry) {
      final wins = entry.value.where((match) => match.isWin).length;
      final losses = entry.value.where((match) => match.isLoss).length;
      final total = entry.value.length;
      return _WinRateStat(
        label: entry.key,
        matches: total,
        wins: wins,
        losses: losses,
        winRate: total == 0 ? 0 : (wins / total) * 100,
      );
    }).toList(growable: false);

    stats.sort((a, b) {
      final rateCompare = a.winRate.compareTo(b.winRate);
      if (rateCompare != 0) {
        return rateCompare;
      }
      return b.matches.compareTo(a.matches);
    });
    return stats;
  }

  List<_CountStat> _buildTagStats(List<MatchRecord> matches, int limit) {
    final sorted = _sortedMatches(matches, descending: true);
    final target = limit == 9999 ? sorted : sorted.take(limit).toList(growable: false);
    final counts = <String, int>{};
    var total = 0;
    for (final match in target) {
      for (final tag in match.issueTags) {
        counts.update(tag, (value) => value + 1, ifAbsent: () => 1);
        total += 1;
      }
    }

    final stats = counts.entries
        .map(
          (entry) => _CountStat(
            label: entry.key,
            count: entry.value,
            ratio: total == 0 ? 0 : entry.value / total,
          ),
        )
        .toList(growable: false);
    stats.sort((a, b) => b.count.compareTo(a.count));
    return stats;
  }

  List<_WinRateValue> _buildMonthlyWinRates(List<MatchRecord> matches) {
    final grouped = <String, List<MatchRecord>>{};
    for (final match in matches) {
      final parsedDate = DateTime.tryParse(match.matchDate ?? '');
      if (parsedDate == null) {
        continue;
      }
      final monthKey =
          '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(monthKey, () => []).add(match);
    }

    final stats = grouped.entries.map((entry) {
      final wins = entry.value.where((match) => match.isWin).length;
      return _WinRateValue(
        label: entry.key,
        winRate: entry.value.isEmpty ? 0 : (wins / entry.value.length) * 100,
      );
    }).toList(growable: false);

    stats.sort((a, b) => a.label.compareTo(b.label));
    return stats;
  }

  List<_MonthlyTagTrend> _buildMonthlyTagTrends(List<MatchRecord> matches) {
    final monthTagCounts = <String, Map<String, int>>{};
    final totalTagCounts = <String, int>{};

    for (final match in matches) {
      final parsedDate = DateTime.tryParse(match.matchDate ?? '');
      if (parsedDate == null || match.issueTags.isEmpty) {
        continue;
      }
      final monthKey =
          '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}';
      final tagCounts = monthTagCounts.putIfAbsent(monthKey, () => {});
      for (final tag in match.issueTags) {
        tagCounts.update(tag, (value) => value + 1, ifAbsent: () => 1);
        totalTagCounts.update(tag, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    if (monthTagCounts.isEmpty) {
      return const [];
    }

    final sortedMonths = monthTagCounts.keys.toList()..sort();
    final topTags = totalTagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return topTags.take(5).map((entry) {
      final monthlyValues = [
        for (final month in sortedMonths)
          _MonthCount(
            month: month,
            count: monthTagCounts[month]?[entry.key] ?? 0,
          ),
      ];
      final maxCount = monthlyValues
          .map((value) => value.count)
          .fold<int>(0, (max, value) => value > max ? value : max);
      return _MonthlyTagTrend(
        tagName: entry.key,
        totalCount: entry.value,
        monthlyValues: monthlyValues,
        maxMonthlyCount: maxCount,
      );
    }).toList(growable: false);
  }

  List<_OpponentStat> _buildOpponentStats(List<MatchRecord> matches) {
    final grouped = <String, List<MatchRecord>>{};
    for (final match in matches) {
      final name = match.opponentName.trim();
      if (name.isEmpty) {
        continue;
      }
      grouped.putIfAbsent(name, () => []).add(match);
    }

    final stats = grouped.entries.map((entry) {
      final sorted = _sortedMatches(entry.value, descending: false);
      final wins = sorted.where((match) => match.isWin).length;
      final losses = sorted.where((match) => match.isLoss).length;
      final lossMatches = sorted.where((match) => match.isLoss).toList(growable: false);
      final lossTagStats = _buildTagStats(lossMatches, 9999);
      final playStyleCounts = <String, int>{};
      for (final match in sorted) {
        if (match.playStyle.trim().isEmpty || match.playStyle == '未選択') {
          continue;
        }
        playStyleCounts.update(match.playStyle, (value) => value + 1, ifAbsent: () => 1);
      }
      final mainStyle = playStyleCounts.entries.isEmpty
          ? '未選択'
          : (playStyleCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
      var cumulativeWins = 0;
      var cumulativeLosses = 0;
      final timeline = <_OpponentTimelineItem>[];
      for (final match in sorted) {
        if (match.isWin) {
          cumulativeWins += 1;
        } else if (match.isLoss) {
          cumulativeLosses += 1;
        }
        timeline.add(
          _OpponentTimelineItem(
            label: '${match.matchDateText} (${match.resultLabel})',
            cumulativeWins: cumulativeWins,
            cumulativeLosses: cumulativeLosses,
          ),
        );
      }

      return _OpponentStat(
        name: entry.key,
        matches: sorted.length,
        wins: wins,
        losses: losses,
        winRate: sorted.isEmpty ? 0 : (wins / sorted.length) * 100,
        mainStyle: mainStyle,
        latestDate: sorted.isEmpty ? '-' : sorted.last.matchDateText,
        timeline: timeline,
        lossTagStats: lossTagStats,
        lossNotes: lossMatches
            .map((match) => match.winLossReason.trim())
            .where((note) => note.isNotEmpty)
            .takeLast(3),
      );
    }).toList(growable: false);

    stats.sort((a, b) {
      final matchesCompare = b.matches.compareTo(a.matches);
      if (matchesCompare != 0) {
        return matchesCompare;
      }
      return a.winRate.compareTo(b.winRate);
    });
    return stats;
  }

  _OverviewStat _buildOverview(
    List<MatchRecord> matches,
    List<_CountStat> currentTagStats,
  ) {
    final totalWins = matches.where((match) => match.isWin).length;
    final totalLosses = matches.where((match) => match.isLoss).length;
    final latest = _sortedMatches(matches, descending: true).firstOrNull;

    return _OverviewStat(
      totalMatches: matches.length,
      totalWins: totalWins,
      totalLosses: totalLosses,
      winRate: matches.isEmpty ? 0 : (totalWins / matches.length) * 100,
      topTagLabel: currentTagStats.isEmpty
          ? 'なし'
          : '${currentTagStats.first.label} (${currentTagStats.first.count})',
      latestMatchLabel: latest == null
          ? '-'
          : '${latest.matchDateText} vs ${latest.opponentName}',
    );
  }

  _OpponentStat? _resolveSelectedOpponent(List<_OpponentStat> stats) {
    if (stats.isEmpty) {
      return null;
    }
    final selected = stats.where((stat) => stat.name == _selectedOpponentName).firstOrNull;
    return selected ?? stats.first;
  }

  Color _tagTrendColor(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      const Color(0xFF00897B),
      const Color(0xFFF4511E),
    ];
    return palette[index % palette.length];
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                    theme.colorScheme.secondary.withValues(alpha: 0.14),
                  ],
                ),
              ),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _RatioBarTile extends StatelessWidget {
  const _RatioBarTile({
    required this.label,
    required this.valueText,
    required this.ratio,
  });

  final String label;
  final String valueText;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueText),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: clamped,
          minHeight: 10,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(trailing),
      ],
    );
  }
}

class _OutcomeTimelineTile extends StatelessWidget {
  const _OutcomeTimelineTile({
    required this.match,
  });

  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWin = match.resultLabel == '勝ち';
    final color = isWin ? theme.colorScheme.primary : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isWin ? Icons.trending_up : Icons.trending_down,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${match.matchDateText} vs ${match.opponentName}'),
          ),
          Text(
            match.resultLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 108),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyTagTrendCard extends StatelessWidget {
  const _MonthlyTagTrendCard({
    required this.trend,
  });

  final _MonthlyTagTrend trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${trend.tagName} (${trend.totalCount}回)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final value in trend.monthlyValues)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RatioBarTile(
                label: value.month,
                valueText: '${value.count}回',
                ratio: trend.maxMonthlyCount == 0
                    ? 0
                    : value.count / trend.maxMonthlyCount,
              ),
            ),
        ],
      ),
    );
  }
}

double mathMaxDouble(List<double> values, {required double fallback}) {
  if (values.isEmpty) {
    return fallback;
  }
  return values.fold<double>(fallback, (max, value) => value > max ? value : max);
}

class _TimelineSummaryRow extends StatelessWidget {
  const _TimelineSummaryRow({
    required this.item,
  });

  final _OpponentTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(item.label)),
        const SizedBox(width: 12),
        Text('累計 ${item.cumulativeWins}勝 ${item.cumulativeLosses}敗'),
      ],
    );
  }
}

class _WinRateStat {
  const _WinRateStat({
    required this.label,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.winRate,
  });

  final String label;
  final int matches;
  final int wins;
  final int losses;
  final double winRate;
}

class _CountStat {
  const _CountStat({
    required this.label,
    required this.count,
    required this.ratio,
  });

  final String label;
  final int count;
  final double ratio;
}

class _WinRateValue {
  const _WinRateValue({
    required this.label,
    required this.winRate,
  });

  final String label;
  final double winRate;
}

class _OpponentStat {
  const _OpponentStat({
    required this.name,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.mainStyle,
    required this.latestDate,
    required this.timeline,
    required this.lossTagStats,
    required this.lossNotes,
  });

  final String name;
  final int matches;
  final int wins;
  final int losses;
  final double winRate;
  final String mainStyle;
  final String latestDate;
  final List<_OpponentTimelineItem> timeline;
  final List<_CountStat> lossTagStats;
  final List<String> lossNotes;
}

class _OpponentTimelineItem {
  const _OpponentTimelineItem({
    required this.label,
    required this.cumulativeWins,
    required this.cumulativeLosses,
  });

  final String label;
  final int cumulativeWins;
  final int cumulativeLosses;
}

class _OverviewStat {
  const _OverviewStat({
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.winRate,
    required this.topTagLabel,
    required this.latestMatchLabel,
  });

  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final double winRate;
  final String topTagLabel;
  final String latestMatchLabel;
}

class _MonthlyTagTrend {
  const _MonthlyTagTrend({
    required this.tagName,
    required this.totalCount,
    required this.monthlyValues,
    required this.maxMonthlyCount,
  });

  final String tagName;
  final int totalCount;
  final List<_MonthCount> monthlyValues;
  final int maxMonthlyCount;
}

class _MonthCount {
  const _MonthCount({
    required this.month,
    required this.count,
  });

  final String month;
  final int count;
}

extension on List<MatchRecord> {
  List<MatchRecord> takeLast(int count) {
    if (length <= count) {
      return this;
    }
    return sublist(length - count);
  }
}

extension on Iterable<String> {
  List<String> takeLast(int count) {
    final values = toList(growable: false);
    if (values.length <= count) {
      return values;
    }
    return values.sublist(values.length - count);
  }
}
