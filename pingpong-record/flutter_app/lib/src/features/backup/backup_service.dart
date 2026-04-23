import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/local/pinpon_database.dart';

class BackupService {
  BackupService({PinponDatabase? database})
      : _database = database ?? PinponDatabase.instance;

  final PinponDatabase _database;

  Future<Directory> get backupDirectory async {
    final baseDir = await getApplicationDocumentsDirectory();
    final target = Directory(p.join(baseDir.path, 'backups'));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  String buildBackupFileName() {
    final now = DateTime.now();
    return 'pinpon-backup-${_stamp(now)}.db';
  }

  String buildPreRestoreBackupFileName() {
    final now = DateTime.now();
    return 'pinpon-before-restore-${_stamp(now)}.db';
  }

  String buildAutoBackupFileName([DateTime? target]) {
    final current = target ?? DateTime.now();
    final datePart =
        '${current.year}${current.month.toString().padLeft(2, '0')}${current.day.toString().padLeft(2, '0')}';
    return 'backup_$datePart.db';
  }

  Future<File> createManualBackup() async {
    final dir = await backupDirectory;
    return _copyCurrentDatabaseTo(
      p.join(dir.path, buildBackupFileName()),
    );
  }

  Future<File> createPreRestoreBackup() async {
    final dir = await backupDirectory;
    return _copyCurrentDatabaseTo(
      p.join(dir.path, buildPreRestoreBackupFileName()),
    );
  }

  Future<File> createAutoBackup() async {
    final dir = await backupDirectory;
    final file = await _copyCurrentDatabaseTo(
      p.join(dir.path, buildAutoBackupFileName()),
    );
    await _pruneAutoBackups();
    return file;
  }

  Future<List<FileSystemEntity>> listAutoBackups() async {
    final dir = await backupDirectory;
    final entities = dir
        .listSync()
        .whereType<File>()
        .where(
          (file) =>
              p.basename(file.path).startsWith('backup_') &&
              p.basename(file.path).endsWith('.db'),
        )
        .toList(growable: false);
    entities.sort((a, b) => b.path.compareTo(a.path));
    return entities;
  }

  Future<void> _pruneAutoBackups({int retentionDays = 7}) async {
    final backups = await listAutoBackups();
    for (final file in backups.skip(retentionDays)) {
      await file.delete();
    }
  }

  Future<File> _copyCurrentDatabaseTo(String targetPath) async {
    await _database.close();
    final sourcePath = await _database.databasePath;
    final targetFile = File(targetPath);
    final parent = targetFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final copied = await File(sourcePath).copy(targetPath);
    await _database.reopen();
    return copied;
  }

  Future<void> shareBackupFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'ピンポンの記録のバックアップファイルです。',
        subject: p.basename(file.path),
      ),
    );
  }

  Future<SelectedBackupFile?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      withData: false,
    );
    final selectedPath = result?.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) {
      return null;
    }
    final file = File(selectedPath);
    final summary = await inspectBackup(file);
    return SelectedBackupFile(file: file, summary: summary);
  }

  Future<BackupSummary> inspectBackup(File file) async {
    Database? database;
    try {
      database = await openDatabase(file.path, readOnly: true);
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final tableNames = {
        for (final row in tables) (row['name'] as String?) ?? '',
      };
      if (!tableNames.contains(PinponDatabase.matchesTable)) {
        throw const BackupException('このファイルには試合データが含まれていません。');
      }

      final matchCount = Sqflite.firstIntValue(
            await database.rawQuery(
              'SELECT COUNT(*) FROM ${PinponDatabase.matchesTable}',
            ),
          ) ??
          0;
      final tagCount = tableNames.contains(PinponDatabase.tagDefinitionsTable)
          ? (Sqflite.firstIntValue(
                    await database.rawQuery(
                      'SELECT COUNT(*) FROM ${PinponDatabase.tagDefinitionsTable}',
                    ),
                  ) ??
              0)
          : 0;
      final dateRows = await database.rawQuery(
        '''
        SELECT MIN(match_date) AS min_date, MAX(match_date) AS max_date
        FROM ${PinponDatabase.matchesTable}
        ''',
      );
      final minDate = dateRows.first['min_date'] as String?;
      final maxDate = dateRows.first['max_date'] as String?;
      final dateRangeText = (minDate == null || maxDate == null)
          ? '日付なし'
          : '$minDate 〜 $maxDate';

      return BackupSummary(
        matchCount: matchCount,
        tagCount: tagCount,
        dateRangeText: dateRangeText,
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(
        'バックアップファイルを読み取れませんでした。アプリで保存したファイルか確認してください。',
      );
    } finally {
      await database?.close();
    }
  }

  Future<File> restoreBackup(File file) async {
    final targetPath = await _database.databasePath;
    await _database.close();
    final restored = await file.copy(targetPath);
    await _database.reopen();
    return restored;
  }

  String _stamp(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '${value.year}$month$day-$hour$minute$second';
  }
}

class BackupSummary {
  const BackupSummary({
    required this.matchCount,
    required this.tagCount,
    required this.dateRangeText,
  });

  final int matchCount;
  final int tagCount;
  final String dateRangeText;
}

class SelectedBackupFile {
  const SelectedBackupFile({
    required this.file,
    required this.summary,
  });

  final File file;
  final BackupSummary summary;
}

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}
