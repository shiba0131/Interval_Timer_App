import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/form_draft.dart';
import '../../data/models/match_record.dart';
import '../../data/repositories/pinpon_repository.dart';
import '../backup/backup_service.dart';
import 'match_form_logic.dart';

class RegisterMatchScreen extends StatelessWidget {
  const RegisterMatchScreen({
    super.key,
    required this.repository,
    this.onDataChanged,
  });

  final PinponRepository repository;
  final VoidCallback? onDataChanged;

  @override
  Widget build(BuildContext context) {
    return MatchFormScreen(
      repository: repository,
      title: '試合結果の登録',
      submitLabel: '試合結果を登録する',
      successMessageBuilder: (match) => '${match.opponentName} 選手との試合結果を登録しました。',
      enableDraft: true,
      onDataChanged: onDataChanged,
    );
  }
}

class EditMatchScreen extends StatelessWidget {
  const EditMatchScreen({
    super.key,
    required this.repository,
    required this.initialMatch,
    this.onDataChanged,
  });

  final PinponRepository repository;
  final MatchRecord initialMatch;
  final VoidCallback? onDataChanged;

  @override
  Widget build(BuildContext context) {
    return MatchFormScreen(
      repository: repository,
      initialMatch: initialMatch,
      title: '記録の修正',
      submitLabel: '変更を保存する',
      successMessageBuilder: (_) => '変更を保存しました。',
      enableDraft: false,
      onDataChanged: onDataChanged,
    );
  }
}

class MatchFormScreen extends StatefulWidget {
  const MatchFormScreen({
    super.key,
    required this.repository,
    required this.title,
    required this.submitLabel,
    required this.successMessageBuilder,
    required this.enableDraft,
    this.onDataChanged,
    this.initialMatch,
  });

  final PinponRepository repository;
  final MatchRecord? initialMatch;
  final String title;
  final String submitLabel;
  final String Function(MatchRecord match) successMessageBuilder;
  final bool enableDraft;
  final VoidCallback? onDataChanged;

  bool get isEdit => initialMatch != null;

  @override
  State<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends State<MatchFormScreen> {
  static const _draftKey = 'new_match_form';
  static const _maxGameCount = 7;

  final _tournamentController = TextEditingController();
  final _opponentController = TextEditingController();
  final _teamController = TextEditingController();
  final _reasonController = TextEditingController();
  final _myScoreControllers =
      List.generate(_maxGameCount, (_) => TextEditingController());
  final _oppScoreControllers =
      List.generate(_maxGameCount, (_) => TextEditingController());
  final BackupService _backupService = BackupService();

  late Future<void> _bootstrapFuture;

  Timer? _draftTimer;
  bool _isInitialized = false;
  bool _isSaving = false;
  bool _autosaveEnabled = false;
  bool _isApplyingScoreAutofill = false;

  DateTime _matchDate = DateTime.now();
  int _gameCount = 5;
  bool _allowIncomplete = false;
  String _playStyle = playStyleOptions.first;
  String _dominantHand = dominantHandOptions.first;
  String _racketGrip = racketGripOptions.first;
  String _foreRubber = rubberOptions.first;
  String _backRubber = rubberOptions.first;
  String _selectedProfileName = '新しく入力する';

  String? _databasePath;
  int _matchCount = 0;
  int _tagCount = 0;
  List<String> _availableTags = [];
  List<String> _selectedTags = [];
  List<OpponentProfile> _profiles = [];
  List<String> _errors = [];
  List<String> _warnings = [];
  String? _successMessage;

  bool get _isEdit => widget.isEdit;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _loadBootstrap();

    for (final controller in [
      _tournamentController,
      _opponentController,
      _teamController,
      _reasonController,
      ..._myScoreControllers,
      ..._oppScoreControllers,
    ]) {
      controller.addListener(_scheduleDraftSave);
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    for (final controller in [
      _tournamentController,
      _opponentController,
      _teamController,
      _reasonController,
      ..._myScoreControllers,
      ..._oppScoreControllers,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBootstrap() async {
    final snapshot = await widget.repository.loadSnapshot();
    final tags = await widget.repository.loadTagDefinitions(includeHidden: false);
    final profiles = await widget.repository.loadOpponentProfiles();
    final draft = widget.enableDraft
        ? await widget.repository.loadDraft(_draftKey)
        : null;

    if (!mounted) {
      return;
    }

    _databasePath = snapshot.databasePath;
    _matchCount = snapshot.matchCount;
    _tagCount = snapshot.tagCount;
    _availableTags = tags.map((tag) => tag.tagName).toList(growable: false);
    _profiles = profiles;

    if (_isEdit) {
      _applyMatch(widget.initialMatch!);
    } else {
      _applyDraft(draft);
    }
    _autosaveEnabled = widget.enableDraft;
    _isInitialized = true;
    setState(() {});
  }

  void _applyMatch(MatchRecord match) {
    _resetFormState(clearMessages: false);

    _matchDate = DateTime.tryParse(match.matchDate ?? '') ?? DateTime.now();
    _gameCount = gameCountOptions.contains(match.gameCount) ? match.gameCount : 5;
    _playStyle = _safeOption(match.playStyle, playStyleOptions);
    _dominantHand = _safeOption(match.dominantHand, dominantHandOptions);
    _racketGrip = _safeOption(match.racketGrip, racketGripOptions);
    _foreRubber = _safeOption(match.foreRubber, rubberOptions);
    _backRubber = _safeOption(match.backRubber, rubberOptions);
    _selectedProfileName = '新しく入力する';

    _tournamentController.text = match.tournamentName;
    _opponentController.text = match.opponentName;
    _teamController.text = match.opponentTeam;
    _reasonController.text = match.winLossReason;
    _selectedTags = [
      for (final tag in match.issueTags)
        if (_availableTags.contains(tag)) tag else tag,
    ];

    for (var i = 0; i < _maxGameCount; i++) {
      final score =
          i < match.scores.length ? match.scores[i] : const ScoreEntry(myScore: 0, oppScore: 0);
      _myScoreControllers[i].text = score.myScore.toString();
      _oppScoreControllers[i].text = score.oppScore.toString();
    }
  }

  void _applyDraft(FormDraft? draft) {
    _resetFormState(clearMessages: false);
    final payload = normalizeDraftPayload(draft?.payload ?? {});

    _matchDate = parseDraftDate(payload['date']);
    _gameCount = intValue(payload['game_count'], fallback: 5);
    if (!gameCountOptions.contains(_gameCount)) {
      _gameCount = 5;
    }
    _allowIncomplete = boolValue(payload['allow_incomplete']);
    _playStyle = _safeOption(
      stringValue(payload['style'], fallback: playStyleOptions.first),
      playStyleOptions,
    );
    _dominantHand = _safeOption(
      stringValue(payload['hand'], fallback: dominantHandOptions.first),
      dominantHandOptions,
    );
    _racketGrip = _safeOption(
      stringValue(payload['grip'], fallback: racketGripOptions.first),
      racketGripOptions,
    );
    _foreRubber = _safeOption(
      stringValue(payload['fore'], fallback: rubberOptions.first),
      rubberOptions,
    );
    _backRubber = _safeOption(
      stringValue(payload['back'], fallback: rubberOptions.first),
      rubberOptions,
    );
    _selectedProfileName =
        stringValue(payload['opp_reuse'], fallback: '新しく入力する');

    _tournamentController.text = stringValue(payload['tour']);
    _opponentController.text = stringValue(payload['opp']);
    _teamController.text = stringValue(payload['team']);
    _reasonController.text = stringValue(payload['reason']);
    _selectedTags = [
      for (final tag in (payload['tags'] as List<String>))
        if (_availableTags.contains(tag)) tag,
    ];

    for (var i = 0; i < _maxGameCount; i++) {
      _myScoreControllers[i].text = intValue(payload['my_${i + 1}']).toString();
      _oppScoreControllers[i].text = intValue(payload['opp_${i + 1}']).toString();
    }
  }

  void _resetFormState({bool clearMessages = true}) {
    _matchDate = DateTime.now();
    _gameCount = 5;
    _allowIncomplete = false;
    _playStyle = playStyleOptions.first;
    _dominantHand = dominantHandOptions.first;
    _racketGrip = racketGripOptions.first;
    _foreRubber = rubberOptions.first;
    _backRubber = rubberOptions.first;
    _selectedProfileName = '新しく入力する';
    _selectedTags = [];

    _tournamentController.clear();
    _opponentController.clear();
    _teamController.clear();
    _reasonController.clear();
    for (final controller in [..._myScoreControllers, ..._oppScoreControllers]) {
      controller.text = '0';
    }

    if (clearMessages) {
      _errors = [];
      _warnings = [];
      _successMessage = null;
    }
  }

  String _safeOption(String value, List<String> options) {
    return options.contains(value) ? value : options.first;
  }

  void _scheduleDraftSave() {
    if (!_autosaveEnabled || !_isInitialized || _isEdit) {
      return;
    }

    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () async {
      await widget.repository.saveDraft(
        FormDraft(
          draftKey: _draftKey,
          payload: _buildDraftPayload(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
    });
  }

  Map<String, Object?> _buildDraftPayload() {
    final payload = <String, Object?>{
      'date': _dateText(_matchDate),
      'tour': _tournamentController.text.trim(),
      'opp': _opponentController.text.trim(),
      'team': _teamController.text.trim(),
      'style': _playStyle,
      'hand': _dominantHand,
      'grip': _racketGrip,
      'fore': _foreRubber,
      'back': _backRubber,
      'game_count': _gameCount,
      'allow_incomplete': _allowIncomplete,
      'tags': _selectedTags,
      'reason': _reasonController.text.trim(),
      'opp_reuse': _selectedProfileName,
    };

    for (var i = 0; i < _maxGameCount; i++) {
      payload['my_${i + 1}'] = _scoreValue(_myScoreControllers[i].text);
      payload['opp_${i + 1}'] = _scoreValue(_oppScoreControllers[i].text);
    }
    return payload;
  }

  List<ScoreEntry> _currentScores() {
    return List.generate(
      _gameCount,
      (index) => ScoreEntry(
        myScore: _scoreValue(_myScoreControllers[index].text),
        oppScore: _scoreValue(_oppScoreControllers[index].text),
      ),
      growable: false,
    );
  }

  int _scoreValue(String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    if (parsed < 0) {
      return 0;
    }
    if (parsed > 50) {
      return 50;
    }
    return parsed;
  }

  void _handleScoreChanged({
    required int index,
    required bool changedMySide,
    required String rawValue,
  }) {
    if (_isApplyingScoreAutofill) {
      return;
    }

    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null || parsed < 0 || parsed > 9) {
      return;
    }

    final targetController =
        changedMySide ? _oppScoreControllers[index] : _myScoreControllers[index];
    if (targetController.text == '11') {
      return;
    }

    _isApplyingScoreAutofill = true;
    targetController.value = TextEditingValue(
      text: '11',
      selection: const TextSelection.collapsed(offset: 2),
    );
    _isApplyingScoreAutofill = false;
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _matchDate = selected;
    });
    _scheduleDraftSave();
  }

  Future<void> _selectProfile(String? profileName) async {
    if (profileName == null || _isEdit) {
      return;
    }

    setState(() {
      _selectedProfileName = profileName;
    });

    if (profileName == '新しく入力する') {
      _scheduleDraftSave();
      return;
    }

    final selected = _profiles.firstWhere(
      (profile) => profile.opponentName == profileName,
    );

    setState(() {
      _opponentController.text = selected.opponentName;
      _teamController.text = selected.opponentTeam;
      _playStyle = _safeOption(selected.playStyle, playStyleOptions);
      _dominantHand = _safeOption(selected.dominantHand, dominantHandOptions);
      _racketGrip = _safeOption(selected.racketGrip, racketGripOptions);
      _foreRubber = _safeOption(selected.foreRubber, rubberOptions);
      _backRubber = _safeOption(selected.backRubber, rubberOptions);
    });

    _scheduleDraftSave();
  }

  Future<void> _discardDraft() async {
    _draftTimer?.cancel();
    _autosaveEnabled = false;
    await widget.repository.deleteDraft(_draftKey);
    setState(() {
      _resetFormState();
    });
    _autosaveEnabled = true;
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('入力中の下書きを破棄しました。')),
    );
  }

  Future<void> _saveMatch() async {
    final opponentName = _opponentController.text.trim();
    if (opponentName.isEmpty) {
      setState(() {
        _errors = ['対戦相手名は必須入力です。'];
        _warnings = [];
        _successMessage = null;
      });
      return;
    }

    final scores = _currentScores();
    final validation = validateScores(
      scores,
      _gameCount,
      allowIncomplete: _allowIncomplete,
    );

    if (validation.errors.isNotEmpty) {
      setState(() {
        _errors = validation.errors;
        _warnings = validation.warnings;
        _successMessage = null;
      });
      return;
    }

    final setCount = calculateSetCount(scores);
    final savingMatch = MatchRecord(
      id: widget.initialMatch?.id,
      createdAt: widget.initialMatch?.createdAt,
      matchDate: _dateText(_matchDate),
      tournamentName: _tournamentController.text.trim(),
      opponentName: opponentName,
      opponentTeam: _teamController.text.trim(),
      playStyle: _playStyle,
      foreRubber: _foreRubber,
      backRubber: _backRubber,
      dominantHand: _dominantHand,
      racketGrip: _racketGrip,
      gameCount: _gameCount,
      mySetCount: setCount.mySets,
      oppSetCount: setCount.oppSets,
      scores: scores,
      winLossReason: _reasonController.text.trim(),
      issueTags: normalizeIssueTags(_selectedTags),
    );

    setState(() {
      _isSaving = true;
      _errors = [];
      _warnings = validation.warnings;
      _successMessage = null;
    });

    try {
      await widget.repository.saveMatch(savingMatch);
      if (widget.enableDraft) {
        await widget.repository.deleteDraft(_draftKey);
      }
      String? backupNotice;
      try {
        final backupFile = await _backupService.createAutoBackup();
        backupNotice = '自動バックアップを更新しました: ${backupFile.path}';
      } catch (backupError) {
        backupNotice = '保存は完了しましたが、自動バックアップに失敗しました: $backupError';
      }
      final snapshot = await widget.repository.loadSnapshot();
      final profiles = await widget.repository.loadOpponentProfiles();

      _autosaveEnabled = false;
      setState(() {
        _databasePath = snapshot.databasePath;
        _matchCount = snapshot.matchCount;
        _tagCount = snapshot.tagCount;
        _availableTags = snapshot.tags
            .where((tag) => !tag.isHidden)
            .map((tag) => tag.tagName)
            .toList(growable: false);
        _profiles = profiles;
        if (_isEdit) {
          _successMessage = widget.successMessageBuilder(savingMatch);
        } else {
          _resetFormState(clearMessages: false);
          _warnings = validation.warnings;
          _successMessage = widget.successMessageBuilder(savingMatch);
        }
        if (backupNotice != null) {
          _warnings = [
            ..._warnings,
            backupNotice,
          ];
        }
      });
      _autosaveEnabled = widget.enableDraft;
      widget.onDataChanged?.call();

      if (!mounted) {
        return;
      }

      final successText = widget.successMessageBuilder(savingMatch);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successText)),
      );

      if (_isEdit) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() {
        _errors = ['保存中にエラーが発生しました: $error'];
        _successMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _toggleTag(String tagName) {
    setState(() {
      if (_selectedTags.contains(tagName)) {
        _selectedTags.remove(tagName);
      } else {
        _selectedTags = [..._selectedTags, tagName];
      }
    });
    _scheduleDraftSave();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${widget.title}の初期化に失敗しました: ${snapshot.error}'),
            ),
          );
        }

        final scores = _currentScores();
        final setCount = calculateSetCount(scores);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                            theme.colorScheme.secondary.withValues(alpha: 0.16),
                          ],
                        ),
                      ),
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _TopStatPill(label: 'DB', value: _databasePath ?? '-'),
                        _TopStatPill(label: '試合数', value: '$_matchCount'),
                        _TopStatPill(label: 'タグ数', value: '$_tagCount'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_successMessage != null)
              _MessageCard(color: Colors.green, messages: [_successMessage!]),
            if (_successMessage != null) const SizedBox(height: 16),
            if (_errors.isNotEmpty)
              _MessageCard(color: theme.colorScheme.error, messages: _errors),
            if (_errors.isNotEmpty) const SizedBox(height: 16),
            if (_warnings.isNotEmpty)
              _MessageCard(color: Colors.orange, messages: _warnings),
            if (_warnings.isNotEmpty) const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('基本情報', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    if (!_isEdit && _profiles.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue:
                            _profiles.any((profile) => profile.opponentName == _selectedProfileName)
                                ? _selectedProfileName
                                : '新しく入力する',
                        decoration: const InputDecoration(
                          labelText: '登録済み相手から再利用',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '新しく入力する',
                            child: Text('新しく入力する'),
                          ),
                          ..._profiles.map(
                            (profile) => DropdownMenuItem(
                              value: profile.opponentName,
                              child: Text(profile.opponentName),
                            ),
                          ),
                        ],
                        onChanged: _selectProfile,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_month),
                            label: Text('日付: ${_dateText(_matchDate)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tournamentController,
                      decoration: const InputDecoration(
                        labelText: '大会名',
                        border: OutlineInputBorder(),
                        hintText: '例: 市民卓球大会',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _opponentController,
                      decoration: const InputDecoration(
                        labelText: '対戦相手名',
                        border: OutlineInputBorder(),
                        hintText: '例: 山田 太郎',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _teamController,
                      decoration: const InputDecoration(
                        labelText: '所属チーム',
                        border: OutlineInputBorder(),
                        hintText: '例: ○○クラブ',
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
                    Text('相手の情報', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _DropdownField(
                      label: '戦型',
                      value: _playStyle,
                      items: playStyleOptions,
                      onChanged: (value) {
                        setState(() {
                          _playStyle = value;
                        });
                        _scheduleDraftSave();
                      },
                    ),
                    const SizedBox(height: 12),
                    _DropdownField(
                      label: '利き手',
                      value: _dominantHand,
                      items: dominantHandOptions,
                      onChanged: (value) {
                        setState(() {
                          _dominantHand = value;
                        });
                        _scheduleDraftSave();
                      },
                    ),
                    const SizedBox(height: 12),
                    _DropdownField(
                      label: 'ラケット',
                      value: _racketGrip,
                      items: racketGripOptions,
                      onChanged: (value) {
                        setState(() {
                          _racketGrip = value;
                        });
                        _scheduleDraftSave();
                      },
                    ),
                    const SizedBox(height: 12),
                    _DropdownField(
                      label: 'フォアラバー',
                      value: _foreRubber,
                      items: rubberOptions,
                      onChanged: (value) {
                        setState(() {
                          _foreRubber = value;
                        });
                        _scheduleDraftSave();
                      },
                    ),
                    const SizedBox(height: 12),
                    _DropdownField(
                      label: 'バックラバー',
                      value: _backRubber,
                      items: rubberOptions,
                      onChanged: (value) {
                        setState(() {
                          _backRubber = value;
                        });
                        _scheduleDraftSave();
                      },
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
                    Text('スコア詳細', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final option in gameCountOptions)
                          ChoiceChip(
                            label: Text('$optionゲーム'),
                            selected: _gameCount == option,
                            onSelected: (_) {
                              setState(() {
                                _gameCount = option;
                              });
                              _scheduleDraftSave();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _gameCount; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _myScoreControllers[i],
                              keyboardType: TextInputType.number,
                              onChanged: (value) => _handleScoreChanged(
                                index: i,
                                changedMySide: true,
                                rawValue: value,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ScoreRangeInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: '第${i + 1}ゲーム 自分',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('-', style: TextStyle(fontSize: 20)),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _oppScoreControllers[i],
                              keyboardType: TextInputType.number,
                              onChanged: (value) => _handleScoreChanged(
                                index: i,
                                changedMySide: false,
                                rawValue: value,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ScoreRangeInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: '第${i + 1}ゲーム 相手',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0D1B2A),
                            theme.colorScheme.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        'セットカウント: 自分 ${setCount.mySets} - ${setCount.oppSets} 相手',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _allowIncomplete,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('相手の棄権・途中終了などで不完全なスコアを保存する'),
                      subtitle: const Text('未決着のゲームや参考スコアも警告扱いで保存します。'),
                      onChanged: (value) {
                        setState(() {
                          _allowIncomplete = value ?? false;
                        });
                        _scheduleDraftSave();
                      },
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
                    Text('振り返り', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tagName in _availableTags)
                          FilterChip(
                            label: Text(tagName),
                            selected: _selectedTags.contains(tagName),
                            onSelected: (_) => _toggleTag(tagName),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reasonController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: '勝因・敗因 / メモ',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isEdit)
              Text(
                '入力内容は端末内に自動保存されます。アプリを開き直しても、新規登録フォームの途中入力を復元できます。',
                style: theme.textTheme.bodySmall,
              ),
            if (!_isEdit) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveMatch,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.submitLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            if (_isEdit) {
                              Navigator.of(context).pop(false);
                            } else {
                              _discardDraft();
                            }
                          },
                    child: Text(_isEdit ? 'キャンセル' : '入力中データを破棄'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(item),
          ),
      ],
      onChanged: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}

class _TopStatPill extends StatelessWidget {
  const _TopStatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.color,
    required this.messages,
  });

  final Color color;
  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final message in messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  message,
                  style: TextStyle(color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRangeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    final parsed = int.tryParse(newValue.text);
    if (parsed == null || parsed > 50) {
      return oldValue;
    }
    return newValue;
  }
}
