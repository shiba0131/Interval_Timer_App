import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/match_record.dart';
import '../../data/repositories/pinpon_repository.dart';
import '../backup/backup_service.dart';
import '../backup/test_data_service.dart';
import '../register/register_match_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.repository,
    required this.refreshSignal,
    required this.onDataChanged,
  });

  final PinponRepository repository;
  final ValueListenable<int> refreshSignal;
  final VoidCallback onDataChanged;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _nameController = TextEditingController();
  final _tournamentController = TextEditingController();
  final BackupService _backupService = BackupService();
  late final TestDataService _testDataService =
      TestDataService(repository: widget.repository);

  late Future<List<MatchRecord>> _matchesFuture;
  String _selectedStyle = 'すべて';
  String _selectedResult = 'すべて';
  int? _selectedMatchId;
  SelectedBackupFile? _selectedBackupFile;
  bool _confirmRestore = false;
  bool _isProcessingBackup = false;
  String? _backupNotice;
  List<FileSystemEntity> _autoBackups = const [];

  @override
  void initState() {
    super.initState();
    _matchesFuture = widget.repository.loadMatches();
    _nameController.addListener(_handleFilterChange);
    _tournamentController.addListener(_handleFilterChange);
    widget.refreshSignal.addListener(_handleExternalRefresh);
    _loadBackupMetadata();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_handleExternalRefresh);
    _nameController.dispose();
    _tournamentController.dispose();
    super.dispose();
  }

  void _handleFilterChange() {
    setState(() {});
  }

  Future<void> _reload() async {
    setState(() {
      _matchesFuture = widget.repository.loadMatches();
    });
    await _matchesFuture;
    await _loadBackupMetadata();
  }

  void _handleExternalRefresh() {
    _reload();
  }

  Future<void> _loadBackupMetadata() async {
    final autoBackups = await _backupService.listAutoBackups();
    if (!mounted) {
      return;
    }
    setState(() {
      _autoBackups = autoBackups;
    });
  }

  Future<void> _openEditScreen(MatchRecord match) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('記録の修正')),
          body: EditMatchScreen(
            repository: widget.repository,
            initialMatch: match,
            onDataChanged: widget.onDataChanged,
          ),
        ),
      ),
    );

    if (result == true) {
      await _reload();
    }
  }

  Future<void> _deleteMatch(MatchRecord match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('試合記録を削除'),
        content: Text('${match.matchDateText} の ${match.opponentName} 戦を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await widget.repository.deleteMatch(match.id!);
    widget.onDataChanged();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('試合記録を削除しました。')),
    );

    if (_selectedMatchId == match.id) {
      setState(() {
        _selectedMatchId = null;
      });
    }
    await _reload();
  }

  Future<void> _shareManualBackup() async {
    setState(() {
      _isProcessingBackup = true;
      _backupNotice = null;
    });

    try {
      final backupFile = await _backupService.createManualBackup();
      await _backupService.shareBackupFile(backupFile);
      if (!mounted) {
        return;
      }
      setState(() {
        _backupNotice = 'バックアップファイルを作成しました: ${backupFile.path}';
      });
      await _loadBackupMetadata();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backupNotice = 'バックアップファイルの作成に失敗しました: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingBackup = false;
        });
      }
    }
  }

  Future<void> _pickRestoreBackup() async {
    setState(() {
      _isProcessingBackup = true;
      _backupNotice = null;
    });

    try {
      final selected = await _backupService.pickBackupFile();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedBackupFile = selected;
        _confirmRestore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backupNotice = 'バックアップファイルを読み込めませんでした: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingBackup = false;
        });
      }
    }
  }

  Future<void> _restoreSelectedBackup() async {
    final selectedBackup = _selectedBackupFile;
    if (selectedBackup == null) {
      return;
    }

    setState(() {
      _isProcessingBackup = true;
      _backupNotice = null;
    });

    try {
      final preRestoreBackup = await _backupService.createPreRestoreBackup();
      await _backupService.restoreBackup(selectedBackup.file);
      widget.onDataChanged();
      await _reload();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedBackupFile = null;
        _confirmRestore = false;
        _selectedMatchId = null;
        _backupNotice =
            'バックアップから復元しました。復元前のデータは ${preRestoreBackup.path} に保存しています。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backupNotice = '復元に失敗しました: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingBackup = false;
        });
      }
    }
  }

  Future<void> _insertSampleData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テストデータを追加'),
        content: const Text(
          'テストデータを 50 件追加します。約 33% は同じ対戦相手になります。既存データは残したまま追加されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('追加する'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isProcessingBackup = true;
      _backupNotice = null;
    });

    try {
      await _testDataService.insertSampleMatches(
        totalCount: 50,
        fixedOpponentCount: 17,
      );
      widget.onDataChanged();
      await _backupService.createAutoBackup();
      await _reload();
      if (!mounted) {
        return;
      }
      setState(() {
        _backupNotice =
            'テストデータを 50 件追加しました。うち 17 件は同一人物です。';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('テストデータを 50 件追加しました。'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backupNotice = 'テストデータの追加に失敗しました: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingBackup = false;
        });
      }
    }
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
              child: Text('履歴データの読み込みに失敗しました: ${snapshot.error}'),
            ),
          );
        }

        final matches = snapshot.data ?? const <MatchRecord>[];
        if (matches.isEmpty) {
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 80),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('履歴がありません。登録タブから試合結果を追加してください。'),
                  ),
                ),
                const SizedBox(height: 16),
                _DeveloperToolsCard(
                  isProcessing: _isProcessingBackup,
                  onInsertSampleData: _insertSampleData,
                ),
                const SizedBox(height: 16),
                _DataProtectionCard(
                  latestAutoBackupPath:
                      _autoBackups.isEmpty ? null : _autoBackups.first.path,
                  selectedBackupFile: _selectedBackupFile,
                  confirmRestore: _confirmRestore,
                  isProcessing: _isProcessingBackup,
                  notice: _backupNotice,
                  onShareBackup: _shareManualBackup,
                  onPickRestoreBackup: _pickRestoreBackup,
                  onConfirmRestoreChanged: (value) {
                    setState(() {
                      _confirmRestore = value;
                    });
                  },
                  onRestore: _restoreSelectedBackup,
                ),
              ],
            ),
          );
        }

        final filteredMatches = _applyFilters(matches);
        final selectedMatch = filteredMatches.where((match) => match.id == _selectedMatchId).firstOrNull ??
            (filteredMatches.isNotEmpty ? filteredMatches.first : null);
        final totalWins = matches.where((match) => match.isWin).length;
        final totalLosses = matches.where((match) => match.isLoss).length;
        final styleOptions = <String>{
          'すべて',
          ...matches.map((match) => match.playStyle).where((style) => style.trim().isNotEmpty),
        }.toList(growable: false);

        if (selectedMatch != null && _selectedMatchId != selectedMatch.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedMatchId = selectedMatch.id;
              });
            }
          });
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: '勝ち',
                          value: '$totalWins',
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: _MetricTile(
                          label: '負け',
                          value: '$totalLosses',
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('検索', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '対戦相手名で検索',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tournamentController,
                        decoration: const InputDecoration(
                          labelText: '大会名で検索',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStyle,
                        decoration: const InputDecoration(
                          labelText: '戦型で絞り込み',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final option in styleOptions)
                            DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedStyle = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedResult,
                        decoration: const InputDecoration(
                          labelText: '勝敗で絞り込み',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'すべて', child: Text('すべて')),
                          DropdownMenuItem(value: '勝ち', child: Text('勝ち')),
                          DropdownMenuItem(value: '負け', child: Text('負け')),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedResult = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text('${filteredMatches.length}件 / ${matches.length}件 を表示中'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (filteredMatches.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('条件に一致する履歴がありません。'),
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('試合一覧', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        for (final match in filteredMatches)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MatchListTile(
                              match: match,
                              selected: match.id == selectedMatch?.id,
                              onTap: () {
                                setState(() {
                                  _selectedMatchId = match.id;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedMatch != null)
                  _MatchDetailCard(
                    match: selectedMatch,
                    onEdit: () => _openEditScreen(selectedMatch),
                    onDelete: () => _deleteMatch(selectedMatch),
                  ),
                const SizedBox(height: 16),
                _DeveloperToolsCard(
                  isProcessing: _isProcessingBackup,
                  onInsertSampleData: _insertSampleData,
                ),
                const SizedBox(height: 16),
                _DataProtectionCard(
                  latestAutoBackupPath:
                      _autoBackups.isEmpty ? null : _autoBackups.first.path,
                  selectedBackupFile: _selectedBackupFile,
                  confirmRestore: _confirmRestore,
                  isProcessing: _isProcessingBackup,
                  notice: _backupNotice,
                  onShareBackup: _shareManualBackup,
                  onPickRestoreBackup: _pickRestoreBackup,
                  onConfirmRestoreChanged: (value) {
                    setState(() {
                      _confirmRestore = value;
                    });
                  },
                  onRestore: _restoreSelectedBackup,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<MatchRecord> _applyFilters(List<MatchRecord> matches) {
    final nameQuery = _nameController.text.trim().toLowerCase();
    final tournamentQuery = _tournamentController.text.trim().toLowerCase();

    return matches.where((match) {
      if (nameQuery.isNotEmpty &&
          !match.opponentName.toLowerCase().contains(nameQuery)) {
        return false;
      }
      if (tournamentQuery.isNotEmpty &&
          !match.tournamentName.toLowerCase().contains(tournamentQuery)) {
        return false;
      }
      if (_selectedStyle != 'すべて' && match.playStyle != _selectedStyle) {
        return false;
      }
      if (_selectedResult != 'すべて' && match.resultLabel != _selectedResult) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }
}

class _DeveloperToolsCard extends StatelessWidget {
  const _DeveloperToolsCard({
    required this.isProcessing,
    required this.onInsertSampleData,
  });

  final bool isProcessing;
  final VoidCallback onInsertSampleData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('開発用', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '分析や履歴表示の確認用に、50 件のテストデータを追加できます。約 33% は同じ対戦相手です。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: isProcessing ? null : onInsertSampleData,
              child: const Text('テストデータを50件追加する'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataProtectionCard extends StatelessWidget {
  const _DataProtectionCard({
    required this.latestAutoBackupPath,
    required this.selectedBackupFile,
    required this.confirmRestore,
    required this.isProcessing,
    required this.notice,
    required this.onShareBackup,
    required this.onPickRestoreBackup,
    required this.onConfirmRestoreChanged,
    required this.onRestore,
  });

  final String? latestAutoBackupPath;
  final SelectedBackupFile? selectedBackupFile;
  final bool confirmRestore;
  final bool isProcessing;
  final String? notice;
  final VoidCallback onShareBackup;
  final VoidCallback onPickRestoreBackup;
  final ValueChanged<bool> onConfirmRestoreChanged;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('データ保護', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'スマホの故障や機種変更に備えて、バックアップの保存と復元ができます。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('バックアップを保存', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              latestAutoBackupPath == null
                  ? '自動バックアップはまだ作成されていません。'
                  : '最新の自動バックアップ: $latestAutoBackupPath',
            ),
            const SizedBox(height: 8),
            Text(
              '今すぐ保存する場合は、下のボタンでバックアップファイルを作成して Files / Google Drive などへ退避してください。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: isProcessing ? null : onShareBackup,
              child: Text(isProcessing ? '処理中...' : 'バックアップファイルを保存する'),
            ),
            const SizedBox(height: 20),
            Text('バックアップから復元', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '保存済みのバックアップファイルを選ぶと、別の端末でもデータを戻せます。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: isProcessing ? null : onPickRestoreBackup,
              child: const Text('保存済みのバックアップファイルを選択'),
            ),
            if (selectedBackupFile != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _BackupMetricPill(
                    label: '試合数',
                    value: '${selectedBackupFile!.summary.matchCount}件',
                  ),
                  _BackupMetricPill(
                    label: 'タグ数',
                    value: '${selectedBackupFile!.summary.tagCount}件',
                  ),
                  _BackupMetricPill(
                    label: '記録期間',
                    value: selectedBackupFile!.summary.dateRangeText,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '復元すると現在のデータは上書きされます。復元前の状態は自動で別バックアップへ退避します。',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: confirmRestore,
                contentPadding: EdgeInsets.zero,
                title: const Text('現在のデータを上書きして復元する'),
                onChanged: isProcessing
                    ? null
                    : (value) => onConfirmRestoreChanged(value ?? false),
              ),
              FilledButton(
                onPressed: !confirmRestore || isProcessing ? null : onRestore,
                child: const Text('このバックアップで復元する'),
              ),
            ],
            if (notice != null) ...[
              const SizedBox(height: 16),
              Text(
                notice!,
                style: TextStyle(
                  color: notice!.contains('失敗')
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupMetricPill extends StatelessWidget {
  const _BackupMetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchListTile extends StatelessWidget {
  const _MatchListTile({
    required this.match,
    required this.selected,
    required this.onTap,
  });

  final MatchRecord match;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${match.matchDateText} vs ${match.opponentName}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _ResultBadge(resultLabel: match.resultLabel),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                match.tournamentName.isEmpty ? '大会名なし' : match.tournamentName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${match.playStyle} | ${match.mySetCount} - ${match.oppSetCount}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchDetailCard extends StatelessWidget {
  const _MatchDetailCard({
    required this.match,
    required this.onEdit,
    required this.onDelete,
  });

  final MatchRecord match;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Text(
                'MATCH DETAIL',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${match.matchDateText} vs ${match.opponentName}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DetailChip(label: '大会名', value: match.tournamentNameOrFallback),
                _DetailChip(label: '所属チーム', value: match.opponentTeamOrFallback),
                _DetailChip(label: '戦型', value: match.playStyle),
                _DetailChip(label: '利き手', value: match.dominantHand),
                _DetailChip(label: 'ラケット', value: match.racketGrip),
                _DetailChip(label: 'フォア', value: match.foreRubber),
                _DetailChip(label: 'バック', value: match.backRubber),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'スコア詳細',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('セットカウント: 自分 ${match.mySetCount} - ${match.oppSetCount} 相手'),
            const SizedBox(height: 8),
            if (match.displayScores.isEmpty)
              const Text('スコアデータなし')
            else
              ...match.displayScores.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(line),
                  )),
            const SizedBox(height: 20),
            Text(
              '振り返り',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('勝敗: ${match.resultLabel}'),
            const SizedBox(height: 4),
            Text('課題タグ: ${match.issueTagsText}'),
            const SizedBox(height: 4),
            Text(
              match.winLossReason.trim().isEmpty
                  ? '勝因・敗因メモなし'
                  : match.winLossReason,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onEdit,
                    child: const Text('この記録を修正する'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDelete,
                    child: const Text('この記録を削除する'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({
    required this.resultLabel,
  });

  final String resultLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWin = resultLabel == '勝ち';
    final backgroundColor =
        isWin ? theme.colorScheme.primaryContainer : theme.colorScheme.errorContainer;
    final foregroundColor =
        isWin ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        resultLabel,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
