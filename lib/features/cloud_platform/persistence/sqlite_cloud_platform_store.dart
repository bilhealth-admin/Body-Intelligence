import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../domain/cloud_identity_models.dart';
import '../domain/cloud_operational_models.dart';
import '../domain/cloud_sync_models.dart';
import '../services/cloud_durable_ports.dart';

final class SqliteCloudPlatformStore implements DurableCloudStore {
  SqliteCloudPlatformStore._(this._db);

  factory SqliteCloudPlatformStore.open(String path) =>
      SqliteCloudPlatformStore._(sqlite3.open(path));

  factory SqliteCloudPlatformStore.inMemory() =>
      SqliteCloudPlatformStore._(sqlite3.openInMemory());

  final Database _db;

  @override
  Future<void> initialize() async {
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute('''
CREATE TABLE IF NOT EXISTS cloud_accounts(
  owner_id TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE TABLE IF NOT EXISTS cloud_devices(
  device_id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  registered_at TEXT NOT NULL,
  revoked_at TEXT
);
CREATE TABLE IF NOT EXISTS cloud_outbox(
  operation_id TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  attempt INTEGER NOT NULL,
  disposition TEXT NOT NULL,
  last_error TEXT,
  next_attempt_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cloud_inbox(
  stable_key TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  payload TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cloud_tombstones(
  stable_key TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  payload TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cloud_cursors(
  owner_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  cursor TEXT,
  PRIMARY KEY(owner_id, device_id)
);
CREATE TABLE IF NOT EXISTS cloud_conflicts(
  conflict_id TEXT PRIMARY KEY,
  stable_key TEXT NOT NULL,
  reason TEXT NOT NULL,
  resolution TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cloud_idempotency(
  idempotency_key TEXT PRIMARY KEY,
  payload_digest TEXT NOT NULL,
  recorded_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cloud_dead_letters(
  operation_id TEXT PRIMARY KEY,
  reason TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  failed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cloud_backups(
  backup_id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  checksum TEXT NOT NULL,
  encrypted_payload TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cloud_audit(
  event_id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  message TEXT NOT NULL,
  severity TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  metadata TEXT NOT NULL
);
''');
  }

  @override
  Future<void> close() async => _db.close();

  @override
  Future<void> upsertAccount(CloudAccount account) async {
    _db.execute('INSERT OR REPLACE INTO cloud_accounts VALUES(?,?,?,?,?)', [
      account.ownerId,
      account.email,
      account.status.name,
      account.createdAt.toIso8601String(),
      account.deletedAt?.toIso8601String(),
    ]);
  }

  @override
  Future<CloudAccount?> readAccount(String ownerId) async {
    final rows = _db.select('SELECT * FROM cloud_accounts WHERE owner_id = ?', [
      ownerId,
    ]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return CloudAccount(
      ownerId: r['owner_id'] as String,
      email: r['email'] as String,
      status: CloudAccountStatus.values.byName(r['status'] as String),
      createdAt: DateTime.parse(r['created_at'] as String),
      deletedAt: r['deleted_at'] == null
          ? null
          : DateTime.parse(r['deleted_at'] as String),
    );
  }

  @override
  Future<void> upsertDevice(CloudDeviceRegistration device) async {
    _db.execute('INSERT OR REPLACE INTO cloud_devices VALUES(?,?,?,?,?)', [
      device.deviceId,
      device.ownerId,
      device.displayName,
      device.registeredAt.toIso8601String(),
      device.revokedAt?.toIso8601String(),
    ]);
  }

  @override
  Future<List<CloudDeviceRegistration>> readDevices(String ownerId) async => _db
      .select(
        'SELECT * FROM cloud_devices WHERE owner_id = ? ORDER BY registered_at',
        [ownerId],
      )
      .map(
        (r) => CloudDeviceRegistration(
          deviceId: r['device_id'] as String,
          ownerId: r['owner_id'] as String,
          displayName: r['display_name'] as String,
          registeredAt: DateTime.parse(r['registered_at'] as String),
          revokedAt: r['revoked_at'] == null
              ? null
              : DateTime.parse(r['revoked_at'] as String),
        ),
      )
      .toList(growable: false);

  @override
  Future<void> revokeDevice(String deviceId, DateTime revokedAt) async =>
      _db.execute(
        'UPDATE cloud_devices SET revoked_at = ? WHERE device_id = ?',
        [revokedAt.toUtc().toIso8601String(), deviceId],
      );

  @override
  Future<void> saveOperation(
    CloudSyncOperation operation, {
    DateTime? nextAttemptAt,
  }) async {
    _db.execute('INSERT OR REPLACE INTO cloud_outbox VALUES(?,?,?,?,?,?)', [
      operation.operationId,
      jsonEncode(_operationToJson(operation)),
      operation.attempt,
      operation.disposition.name,
      operation.lastError,
      (nextAttemptAt ?? operation.createdAt).toUtc().toIso8601String(),
    ]);
  }

  @override
  Future<List<CloudSyncOperation>> readReadyOperations({
    required String ownerId,
    required DateTime now,
    required int limit,
  }) async => _db
      .select(
        '''SELECT payload FROM cloud_outbox
           WHERE next_attempt_at <= ?
             AND json_extract(payload, '\$.record.ownerId') = ?
           ORDER BY next_attempt_at LIMIT ?''',
        [now.toUtc().toIso8601String(), ownerId, limit],
      )
      .map(
        (r) => _operationFromJson(
          jsonDecode(r['payload'] as String) as Map<String, Object?>,
        ),
      )
      .toList(growable: false);

  @override
  Future<void> acknowledgeOperations(Iterable<String> ids) async {
    for (final id in ids) {
      _db.execute('DELETE FROM cloud_outbox WHERE operation_id = ?', [id]);
    }
  }

  @override
  Future<void> markRetry(
    CloudSyncOperation operation,
    DateTime nextAttemptAt,
  ) => saveOperation(operation, nextAttemptAt: nextAttemptAt);

  @override
  Future<void> moveToDeadLetter(CloudDeadLetter deadLetter) async {
    _db.execute('DELETE FROM cloud_outbox WHERE operation_id = ?', [
      deadLetter.operationId,
    ]);
    _db.execute('INSERT OR REPLACE INTO cloud_dead_letters VALUES(?,?,?,?)', [
      deadLetter.operationId,
      deadLetter.reason,
      deadLetter.attempts,
      deadLetter.failedAt.toIso8601String(),
    ]);
  }

  @override
  Future<List<CloudDeadLetter>> readDeadLetters() async => _db
      .select('SELECT * FROM cloud_dead_letters ORDER BY failed_at')
      .map(
        (r) => CloudDeadLetter(
          operationId: r['operation_id'] as String,
          reason: r['reason'] as String,
          attempts: r['attempts'] as int,
          failedAt: DateTime.parse(r['failed_at'] as String),
        ),
      )
      .toList(growable: false);

  @override
  Future<void> saveInboxRecord(CloudRecordEnvelope record) async => _db.execute(
    'INSERT OR REPLACE INTO cloud_inbox VALUES(?,?,?)',
    [record.stableKey, record.ownerId, jsonEncode(_recordToJson(record))],
  );

  @override
  Future<CloudRecordEnvelope?> readInboxRecord(String stableKey) async {
    final rows = _db.select(
      'SELECT payload FROM cloud_inbox WHERE stable_key = ?',
      [stableKey],
    );
    return rows.isEmpty
        ? null
        : _recordFromJson(
            jsonDecode(rows.first['payload'] as String) as Map<String, Object?>,
          );
  }

  @override
  Future<List<CloudRecordEnvelope>> readAllRecords(String ownerId) async => _db
      .select(
        'SELECT payload FROM cloud_inbox WHERE owner_id = ? ORDER BY stable_key',
        [ownerId],
      )
      .map(
        (r) => _recordFromJson(
          jsonDecode(r['payload'] as String) as Map<String, Object?>,
        ),
      )
      .toList(growable: false);

  @override
  Future<void> saveTombstone(CloudRecordEnvelope record) async => _db.execute(
    'INSERT OR REPLACE INTO cloud_tombstones VALUES(?,?,?)',
    [record.stableKey, record.ownerId, jsonEncode(_recordToJson(record))],
  );

  @override
  Future<List<CloudRecordEnvelope>> readTombstones(String ownerId) async => _db
      .select('SELECT payload FROM cloud_tombstones WHERE owner_id = ?', [
        ownerId,
      ])
      .map(
        (r) => _recordFromJson(
          jsonDecode(r['payload'] as String) as Map<String, Object?>,
        ),
      )
      .toList(growable: false);

  @override
  Future<void> saveConflict(CloudConflictRecord conflict) async =>
      _db.execute('INSERT OR REPLACE INTO cloud_conflicts VALUES(?,?,?,?,?)', [
        conflict.conflictId,
        conflict.stableKey,
        conflict.reason,
        conflict.resolution.name,
        conflict.createdAt.toIso8601String(),
      ]);

  @override
  Future<List<CloudConflictRecord>> readConflicts() async => _db
      .select('SELECT * FROM cloud_conflicts ORDER BY created_at')
      .map(
        (r) => CloudConflictRecord(
          conflictId: r['conflict_id'] as String,
          stableKey: r['stable_key'] as String,
          reason: r['reason'] as String,
          resolution: CloudConflictResolution.values.byName(
            r['resolution'] as String,
          ),
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
      )
      .toList(growable: false);

  @override
  Future<String?> readCursor(String ownerId, String deviceId) async {
    final rows = _db.select(
      'SELECT cursor FROM cloud_cursors WHERE owner_id = ? AND device_id = ?',
      [ownerId, deviceId],
    );
    return rows.isEmpty ? null : rows.first['cursor'] as String?;
  }

  @override
  Future<void> saveCursor(
    String ownerId,
    String deviceId,
    String? cursor,
  ) async => _db.execute('INSERT OR REPLACE INTO cloud_cursors VALUES(?,?,?)', [
    ownerId,
    deviceId,
    cursor,
  ]);

  @override
  Future<bool> hasIdempotencyKey(String key) async => _db.select(
    'SELECT 1 FROM cloud_idempotency WHERE idempotency_key = ?',
    [key],
  ).isNotEmpty;

  @override
  Future<void> saveIdempotencyReceipt(CloudIdempotencyReceipt receipt) async =>
      _db.execute('INSERT OR IGNORE INTO cloud_idempotency VALUES(?,?,?)', [
        receipt.key,
        receipt.payloadDigest,
        receipt.recordedAt.toIso8601String(),
      ]);

  @override
  Future<void> saveBackup(CloudBackupArtifact backup) async =>
      _db.execute('INSERT OR REPLACE INTO cloud_backups VALUES(?,?,?,?,?,?)', [
        backup.backupId,
        backup.ownerId,
        backup.schemaVersion,
        backup.checksum,
        jsonEncode(backup.encryptedPayload),
        backup.createdAt.toIso8601String(),
      ]);

  @override
  Future<CloudBackupArtifact?> readBackup(String backupId) async {
    final rows = _db.select('SELECT * FROM cloud_backups WHERE backup_id = ?', [
      backupId,
    ]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return CloudBackupArtifact(
      backupId: r['backup_id'] as String,
      ownerId: r['owner_id'] as String,
      schemaVersion: r['schema_version'] as int,
      checksum: r['checksum'] as String,
      encryptedPayload:
          jsonDecode(r['encrypted_payload'] as String) as Map<String, Object?>,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }

  @override
  Future<void> replaceOwnerRecords(
    String ownerId,
    Iterable<CloudRecordEnvelope> records,
  ) async {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute('DELETE FROM cloud_inbox WHERE owner_id = ?', [ownerId]);
      for (final record in records) {
        await saveInboxRecord(record);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> deleteOwnerData(String ownerId) async {
    for (final table in [
      'cloud_accounts',
      'cloud_devices',
      'cloud_inbox',
      'cloud_tombstones',
      'cloud_cursors',
      'cloud_backups',
    ]) {
      _db.execute('DELETE FROM $table WHERE owner_id = ?', [ownerId]);
    }
    _db.execute(
      "DELETE FROM cloud_outbox WHERE json_extract(payload, '\$.record.ownerId') = ?",
      [ownerId],
    );
  }

  @override
  Future<void> appendAudit(CloudAuditEvent event) async =>
      _db.execute('INSERT OR REPLACE INTO cloud_audit VALUES(?,?,?,?,?,?)', [
        event.eventId,
        event.category,
        event.message,
        event.severity.name,
        event.occurredAt.toIso8601String(),
        jsonEncode(event.redactedMetadata),
      ]);

  @override
  Future<List<CloudAuditEvent>> readAudit({int limit = 100}) async => _db
      .select('SELECT * FROM cloud_audit ORDER BY occurred_at DESC LIMIT ?', [
        limit,
      ])
      .map(
        (r) => CloudAuditEvent(
          eventId: r['event_id'] as String,
          category: r['category'] as String,
          message: r['message'] as String,
          severity: CloudAuditSeverity.values.byName(r['severity'] as String),
          occurredAt: DateTime.parse(r['occurred_at'] as String),
          redactedMetadata:
              jsonDecode(r['metadata'] as String) as Map<String, Object?>,
        ),
      )
      .toList(growable: false);

  @override
  Future<int> pendingCount({String? ownerId}) async => ownerId == null
      ? (_db.select('SELECT COUNT(*) AS c FROM cloud_outbox').first['c'] as int)
      : (_db.select(
              "SELECT COUNT(*) AS c FROM cloud_outbox WHERE json_extract(payload, '\$.record.ownerId') = ?",
              [ownerId],
            ).first['c']
            as int);
  @override
  Future<int> deadLetterCount() async =>
      (_db.select('SELECT COUNT(*) AS c FROM cloud_dead_letters').first['c']
          as int);
  @override
  Future<int> conflictCount() async =>
      (_db.select('SELECT COUNT(*) AS c FROM cloud_conflicts').first['c']
          as int);

  static Map<String, Object?> _revisionToJson(CloudRevision r) => {
    'deviceId': r.deviceId,
    'sequence': r.sequence,
  };
  static CloudRevision _revisionFromJson(Map<String, Object?> j) =>
      CloudRevision(
        deviceId: j['deviceId']! as String,
        sequence: j['sequence']! as int,
      );
  static Map<String, Object?> _recordToJson(CloudRecordEnvelope r) => {
    'entityKind': r.entityKind.name,
    'recordId': r.recordId,
    'ownerId': r.ownerId,
    'revision': _revisionToJson(r.revision),
    'updatedAt': r.updatedAt.toIso8601String(),
    'deletedAt': r.deletedAt?.toIso8601String(),
    'schemaVersion': r.schemaVersion,
    'payload': r.payload,
  };
  static CloudRecordEnvelope _recordFromJson(Map<String, Object?> j) =>
      CloudRecordEnvelope(
        entityKind: CloudEntityKind.values.byName(j['entityKind']! as String),
        recordId: j['recordId']! as String,
        ownerId: j['ownerId']! as String,
        revision: _revisionFromJson(
          (j['revision']! as Map).cast<String, Object?>(),
        ),
        updatedAt: DateTime.parse(j['updatedAt']! as String),
        deletedAt: j['deletedAt'] == null
            ? null
            : DateTime.parse(j['deletedAt']! as String),
        schemaVersion: j['schemaVersion']! as int,
        payload: (j['payload']! as Map).cast<String, Object?>(),
      );
  static Map<String, Object?> _operationToJson(CloudSyncOperation o) => {
    'operationId': o.operationId,
    'mutation': o.mutation.name,
    'record': _recordToJson(o.record),
    'createdAt': o.createdAt.toIso8601String(),
    'attempt': o.attempt,
    'disposition': o.disposition.name,
    'lastError': o.lastError,
  };
  static CloudSyncOperation _operationFromJson(Map<String, Object?> j) =>
      CloudSyncOperation(
        operationId: j['operationId']! as String,
        mutation: CloudMutationKind.values.byName(j['mutation']! as String),
        record: _recordFromJson((j['record']! as Map).cast<String, Object?>()),
        createdAt: DateTime.parse(j['createdAt']! as String),
        attempt: j['attempt']! as int,
        disposition: CloudSyncDisposition.values.byName(
          j['disposition']! as String,
        ),
        lastError: j['lastError'] as String?,
      );
}
