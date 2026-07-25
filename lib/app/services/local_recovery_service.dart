import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../data/database/app_database.dart';
import 'local_data_lifecycle_service.dart';

typedef RecoveryDirectoryResolver = Future<Directory> Function();

class RecoverySnapshotException implements Exception {
  const RecoverySnapshotException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocalRecoveryService {
  LocalRecoveryService(
    this.database, {
    RecoveryDirectoryResolver? directoryResolver,
  }) : _directoryResolver = directoryResolver ?? getApplicationSupportDirectory;

  static const snapshotFormatVersion = 1;
  static const _fileName = 'bil_local_recovery_v1.sqlite';
  static const _tables = <String>[
    'daily_logs',
    'user_profile',
    'weight_entries',
    'foods',
    'meals',
    'meal_items',
    'favorites',
    'recent_foods',
    'goals',
    'water_entries',
    'preferences',
    'life_context_entries',
    'decision_memories',
    'plan_settings',
    'personal_experiments',
    'challenges',
  ];

  final AppDatabase database;
  final RecoveryDirectoryResolver _directoryResolver;
  bool _restoring = false;

  Future<File> _snapshotFile() async {
    final root = await _directoryResolver();
    final directory = Directory(path.join(root.path, 'recovery'));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final target = File(path.join(directory.path, _fileName));
    final previous = File('${target.path}.previous');
    if (!target.existsSync() && previous.existsSync()) {
      await previous.rename(target.path);
    }
    return target;
  }

  Future<bool> hasValidSnapshot() async {
    final file = await _snapshotFile();
    if (!file.existsSync()) return false;
    try {
      _validate(file);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> createSnapshot() async {
    final target = await _snapshotFile();
    final temporary = File('${target.path}.tmp');
    if (temporary.existsSync()) await temporary.delete();

    final escaped = temporary.path.replaceAll("'", "''");
    await database.customStatement("VACUUM INTO '$escaped'");

    final snapshot = sqlite3.open(temporary.path);
    try {
      snapshot.execute(
        'CREATE TABLE bil_recovery_metadata ('
        'format_version INTEGER NOT NULL, '
        'schema_version INTEGER NOT NULL, '
        'created_at TEXT NOT NULL)',
      );
      snapshot.execute('INSERT INTO bil_recovery_metadata VALUES (?, ?, ?)', [
        snapshotFormatVersion,
        database.schemaVersion,
        DateTime.now().toUtc().toIso8601String(),
      ]);
    } finally {
      snapshot.close();
    }

    _validate(temporary);
    final previous = File('${target.path}.previous');
    if (previous.existsSync()) await previous.delete();
    if (target.existsSync()) await target.rename(previous.path);
    try {
      await temporary.rename(target.path);
    } catch (_) {
      if (!target.existsSync() && previous.existsSync()) {
        await previous.rename(target.path);
      }
      rethrow;
    }
    _validate(target);
    if (previous.existsSync()) await previous.delete();
  }

  Future<void> resetWithRecovery() async {
    await createSnapshot();
    await LocalDataLifecycleService(database).clearAll();
  }

  Future<void> restore() async {
    if (_restoring) {
      throw const RecoverySnapshotException(
        'A local restore is already in progress.',
      );
    }
    _restoring = true;
    try {
      final snapshot = await _snapshotFile();
      _validate(snapshot);
      final escaped = snapshot.path.replaceAll("'", "''");
      await database.customStatement("ATTACH DATABASE '$escaped' AS recovery");
      try {
        await database.transaction(() async {
          for (final table in _tables.reversed) {
            await database.customStatement('DELETE FROM main.$table');
          }
          for (final table in _tables) {
            await database.customStatement(
              'INSERT INTO main.$table SELECT * FROM recovery.$table',
            );
          }
        });
      } finally {
        await database.customStatement('DETACH DATABASE recovery');
      }
      final result = await database
          .customSelect('PRAGMA integrity_check')
          .getSingle();
      if (result.data.values.single != 'ok') {
        throw const RecoverySnapshotException(
          'Restored local data failed integrity validation.',
        );
      }
    } finally {
      _restoring = false;
    }
  }

  void _validate(File file) {
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw const RecoverySnapshotException(
        'No valid local recovery snapshot exists.',
      );
    }
    final snapshot = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final integrity = snapshot.select('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const RecoverySnapshotException(
          'The local recovery snapshot is damaged.',
        );
      }
      final metadata = snapshot.select(
        'SELECT format_version, schema_version '
        'FROM bil_recovery_metadata LIMIT 1',
      );
      if (metadata.isEmpty ||
          metadata.first['format_version'] != snapshotFormatVersion ||
          metadata.first['schema_version'] != database.schemaVersion) {
        throw const RecoverySnapshotException(
          'The local recovery snapshot is incompatible.',
        );
      }
      for (final table in _tables) {
        final found = snapshot.select(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (found.isEmpty) {
          throw const RecoverySnapshotException(
            'The local recovery snapshot is incomplete.',
          );
        }
      }
    } finally {
      snapshot.close();
    }
  }
}
