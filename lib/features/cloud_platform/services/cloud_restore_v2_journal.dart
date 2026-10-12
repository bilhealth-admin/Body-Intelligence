import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database/app_database.dart';

/// Local-only durable journal in the SAME database as restored records. This
/// allows cursor, relational application and baseline to commit atomically.
/// It is deliberately additive and is not exported as user goal preferences.
final class CloudRestoreV2Journal {
  const CloudRestoreV2Journal(this.database, this.ownerId);
  final AppDatabase database;
  final String ownerId;

  Future<void> initialize() async {
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS bil_local_restore_dataset_v2 (
        owner_id TEXT PRIMARY KEY, token TEXT NOT NULL)''');
    await database.customStatement(
      '''
      CREATE TABLE IF NOT EXISTS bil_local_restore_recovery_v2 (
        id INTEGER PRIMARY KEY AUTOINCREMENT, owner_id TEXT NOT NULL,
        record_key TEXT NOT NULL, saved_at TEXT NOT NULL, preimage TEXT NOT NULL)''',
    );
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS bil_local_restore_v2 (
        owner_id TEXT NOT NULL, record_key TEXT NOT NULL,
        scope TEXT NOT NULL, record_type TEXT NOT NULL, record_id TEXT NOT NULL,
        server_revision INTEGER NOT NULL DEFAULT 0,
        baseline TEXT, pending TEXT, pending_snapshot TEXT, conflict TEXT,
        recovery TEXT,
        PRIMARY KEY(owner_id, record_key))''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS bil_local_restore_cursor_v2 (
        owner_id TEXT NOT NULL, scope TEXT NOT NULL, cursor INTEGER NOT NULL,
        PRIMARY KEY(owner_id, scope))''');
    await database.transaction(() async {
      final markerKey = 'cloud.restore.dataset.v2.$ownerId';
      final marker = await (database.select(
        database.preferences,
      )..where((row) => row.key.equals(markerKey))).getSingleOrNull();
      final stored = await database
          .customSelect(
            'SELECT token FROM bil_local_restore_dataset_v2 WHERE owner_id=?',
            variables: [Variable(ownerId)],
          )
          .getSingleOrNull();
      final priorToken = stored?.read<String>('token');
      if (priorToken != null && marker?.value != priorToken) {
        // A local reset or SQLite recovery replaced the dataset, not a user
        // request to delete its cloud backup. Preserve pending preimages and
        // restart download from zero; never synthesize remote deletions here.
        final prior = await database
            .customSelect(
              'SELECT * FROM bil_local_restore_v2 WHERE owner_id=?',
              variables: [Variable(ownerId)],
            )
            .get();
        for (final row in prior) {
          await preserve(row.read<String>('record_key'), {
            'dataset_reset': true,
            'journal': row.data,
          });
        }
        await database.customStatement(
          'DELETE FROM bil_local_restore_v2 WHERE owner_id=?',
          [ownerId],
        );
        await database.customStatement(
          'DELETE FROM bil_local_restore_cursor_v2 WHERE owner_id=?',
          [ownerId],
        );
      }
      final token = marker?.value ?? const Uuid().v4();
      await database.customStatement(
        'INSERT INTO bil_local_restore_dataset_v2(owner_id,token) VALUES(?,?) '
        'ON CONFLICT(owner_id) DO UPDATE SET token=excluded.token',
        [ownerId, token],
      );
      if (marker == null) {
        await database
            .into(database.preferences)
            .insertOnConflictUpdate(
              PreferencesCompanion.insert(key: markerKey, value: token),
            );
      }
    });
  }

  Future<void> preserve(String key, Map<String, Object?> preimage) =>
      database.customStatement(
        '''INSERT INTO bil_local_restore_recovery_v2
        (owner_id,record_key,saved_at,preimage) VALUES(?,?,?,?)''',
        [
          ownerId,
          key,
          DateTime.now().toUtc().toIso8601String(),
          jsonEncode(preimage),
        ],
      );

  Future<List<RestoreJournalEntry>> entries(String scope) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM bil_local_restore_v2 WHERE owner_id = ? AND scope = ? ORDER BY record_key',
          variables: [Variable(ownerId), Variable(scope)],
        )
        .get();
    return rows.map((row) => RestoreJournalEntry.fromMap(row.data)).toList();
  }

  Future<RestoreJournalEntry?> entry(String key) async {
    final row = await database
        .customSelect(
          'SELECT * FROM bil_local_restore_v2 WHERE owner_id = ? AND record_key = ?',
          variables: [Variable(ownerId), Variable(key)],
        )
        .getSingleOrNull();
    return row == null ? null : RestoreJournalEntry.fromMap(row.data);
  }

  Future<void> save(RestoreJournalEntry row) => database.customStatement(
    '''
    INSERT INTO bil_local_restore_v2
    (owner_id,record_key,scope,record_type,record_id,server_revision,
     baseline,pending,pending_snapshot,conflict,recovery)
    VALUES (?,?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(owner_id,record_key) DO UPDATE SET
      server_revision=excluded.server_revision,baseline=excluded.baseline,
      pending=excluded.pending,pending_snapshot=excluded.pending_snapshot,
      conflict=excluded.conflict,recovery=excluded.recovery''',
    [
      ownerId,
      row.key,
      row.scope,
      row.type,
      row.id,
      row.revision,
      row.baseline,
      _encode(row.pending),
      _encode(row.pendingSnapshot),
      _encode(row.conflict),
      _encode(row.recovery),
    ],
  );

  Future<int> cursor(String scope) async {
    final row = await database
        .customSelect(
          'SELECT cursor FROM bil_local_restore_cursor_v2 WHERE owner_id = ? AND scope = ?',
          variables: [Variable(ownerId), Variable(scope)],
        )
        .getSingleOrNull();
    return row?.read<int>('cursor') ?? 0;
  }

  Future<void> advance(String scope, int value) => database.customStatement(
    '''
    INSERT INTO bil_local_restore_cursor_v2(owner_id,scope,cursor) VALUES(?,?,?)
    ON CONFLICT(owner_id,scope) DO UPDATE SET cursor=excluded.cursor''',
    [ownerId, scope, value],
  );

  static String? _encode(Object? value) =>
      value == null ? null : jsonEncode(value);
}

final class RestoreJournalEntry {
  RestoreJournalEntry({
    required this.scope,
    required this.type,
    required this.id,
  });
  final String scope;
  final String type;
  final String id;
  String get key => '$scope:$type:$id';
  int revision = 0;
  String? baseline;
  Map<String, Object?>? pending;
  Map<String, Object?>? pendingSnapshot;
  Map<String, Object?>? conflict;
  Map<String, Object?>? recovery;

  factory RestoreJournalEntry.fromMap(Map<String, Object?> row) {
    Map<String, Object?>? decode(String field) => row[field] == null
        ? null
        : Map<String, Object?>.from(jsonDecode(row[field]! as String) as Map);
    return RestoreJournalEntry(
        scope: row['scope']! as String,
        type: row['record_type']! as String,
        id: row['record_id']! as String,
      )
      ..revision = row['server_revision']! as int
      ..baseline = row['baseline'] as String?
      ..pending = decode('pending')
      ..pendingSnapshot = decode('pending_snapshot')
      ..conflict = decode('conflict')
      ..recovery = decode('recovery');
  }
}
