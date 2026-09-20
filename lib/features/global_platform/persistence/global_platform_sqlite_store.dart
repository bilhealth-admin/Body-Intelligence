import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';
import 'package:crypto/crypto.dart';
import '../core/global_platform_core.dart';

final class SqliteGlobalPlatformStore implements GlobalDurableStore {
  SqliteGlobalPlatformStore(Database db) : _db = db {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS global_records(
        bucket TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        schema_version INTEGER,
        revision INTEGER,
        checksum TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(bucket,key)
      )
    ''');
    _db.execute(
      'CREATE INDEX IF NOT EXISTS idx_global_records_bucket_updated '
      'ON global_records(bucket, updated_at)',
    );
    _db.execute('''
      CREATE TABLE IF NOT EXISTS global_store_migrations(
        id INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL
      )
    ''');
  }

  factory SqliteGlobalPlatformStore.memory() =>
      SqliteGlobalPlatformStore(sqlite3.openInMemory());

  final Database _db;

  @override
  Future<void> put(
    String bucket,
    String key,
    Map<String, Object?> value,
  ) async {
    final encoded = jsonEncode(value);
    if (encoded.length > 2 * 1024 * 1024) {
      throw StateError('global_store_payload_limit');
    }
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        '''
        INSERT INTO global_records(
          bucket,key,value,schema_version,revision,checksum,updated_at
        ) VALUES(?,?,?,?,?,?,?)
        ON CONFLICT(bucket,key) DO UPDATE SET
          value=excluded.value,
          schema_version=excluded.schema_version,
          revision=excluded.revision,
          checksum=excluded.checksum,
          updated_at=excluded.updated_at
        ''',
        <Object?>[
          bucket,
          key,
          encoded,
          value['version'] is int ? value['version'] : null,
          value['revision'] is int ? value['revision'] : null,
          value['checksum'] as String?,
          value['updatedAt'] as String? ??
              DateTime.now().toUtc().toIso8601String(),
        ],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<Map<String, Object?>?> get(String bucket, String key) async {
    final rows = _db.select(
      'SELECT value FROM global_records WHERE bucket=? AND key=?',
      <Object?>[bucket, key],
    );
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, Object?>.from(
      jsonDecode(rows.first['value'] as String) as Map,
    );
  }

  @override
  Future<List<Map<String, Object?>>> list(
    String bucket,
  ) async => <Map<String, Object?>>[
    for (final row in _db.select(
      'SELECT value FROM global_records WHERE bucket=? ORDER BY updated_at,key',
      <Object?>[bucket],
    ))
      Map<String, Object?>.from(jsonDecode(row['value'] as String) as Map),
  ];

  Future<List<Map<String, Object?>>> queryUpdatedAfter(
    String bucket,
    DateTime instant,
  ) async => <Map<String, Object?>>[
    for (final row in _db.select(
      'SELECT value FROM global_records '
      'WHERE bucket=? AND updated_at>? ORDER BY updated_at,key',
      <Object?>[bucket, instant.toUtc().toIso8601String()],
    ))
      Map<String, Object?>.from(jsonDecode(row['value'] as String) as Map),
  ];

  Future<void> retain(
    String bucket, {
    required DateTime oldestAllowed,
    required int maximumRecords,
  }) async {
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'DELETE FROM global_records WHERE bucket=? AND updated_at<?',
        <Object?>[bucket, oldestAllowed.toUtc().toIso8601String()],
      );
      final overflow = _db.select(
        'SELECT key FROM global_records WHERE bucket=? '
        'ORDER BY updated_at DESC,key DESC LIMIT -1 OFFSET ?',
        <Object?>[bucket, maximumRecords],
      );
      for (final row in overflow) {
        _db.execute(
          'DELETE FROM global_records WHERE bucket=? AND key=?',
          <Object?>[bucket, row['key']],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> verifyIntegrity() async {
    final result = _db.select('PRAGMA quick_check');
    if (result.isEmpty || result.first.values.first != 'ok') {
      throw StateError('global_store_integrity_failure');
    }
    for (final row in _db.select(
      'SELECT bucket,key,value FROM global_records',
    )) {
      try {
        jsonDecode(row['value'] as String);
      } catch (_) {
        throw StateError(
          'global_store_corruption:${row['bucket']}:${row['key']}',
        );
      }
    }
  }

  @override
  Future<void> remove(String bucket, String key) async => _db.execute(
    'DELETE FROM global_records WHERE bucket=? AND key=?',
    <Object?>[bucket, key],
  );

  @override
  Future<void> clear(String bucket) async => _db.execute(
    'DELETE FROM global_records WHERE bucket=?',
    <Object?>[bucket],
  );

  Future<int> compareAndSwap({
    required String bucket,
    required String key,
    required int expectedRevision,
    required Map<String, Object?> nextValue,
  }) async {
    final encoded = jsonEncode(nextValue);
    _db.execute('BEGIN IMMEDIATE');
    try {
      _db.execute(
        'UPDATE global_records SET value=?,schema_version=?,revision=?,checksum=?,updated_at=? '
        'WHERE bucket=? AND key=? AND revision=?',
        <Object?>[
          encoded,
          nextValue['version'] as int?,
          nextValue['revision'] as int?,
          nextValue['checksum'] as String?,
          nextValue['updatedAt'] as String? ??
              DateTime.now().toUtc().toIso8601String(),
          bucket,
          key,
          expectedRevision,
        ],
      );
      final changed = _db.updatedRows;
      if (changed != 1) {
        _db.execute('ROLLBACK');
        throw StateError('optimistic_concurrency_conflict');
      }
      _db.execute('COMMIT');
      return changed;
    } catch (_) {
      try {
        _db.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> applyMigration({
    required int id,
    required String checksum,
    required List<String> statements,
  }) async {
    _db.execute(
      'CREATE TABLE IF NOT EXISTS global_store_migrations_v2('
      'id INTEGER PRIMARY KEY,checksum TEXT NOT NULL,applied_at TEXT NOT NULL)',
    );
    final existing = _db.select(
      'SELECT checksum FROM global_store_migrations_v2 WHERE id=?',
      <Object?>[id],
    );
    if (existing.isNotEmpty) {
      if (existing.first['checksum'] != checksum) {
        throw StateError('migration_checksum_mismatch:$id');
      }
      return;
    }
    _db.execute('BEGIN IMMEDIATE');
    try {
      for (final sql in statements) {
        _db.execute(sql);
      }
      _db.execute(
        'INSERT INTO global_store_migrations_v2(id,checksum,applied_at) VALUES(?,?,?)',
        <Object?>[id, checksum, DateTime.now().toUtc().toIso8601String()],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> verifyEnvelopeChecksums() async {
    for (final row in _db.select(
      'SELECT bucket,key,value,checksum FROM global_records',
    )) {
      final decoded = Map<String, Object?>.from(
        jsonDecode(row['value'] as String) as Map,
      );
      final payload = decoded['payload'];
      final expected = row['checksum'] as String?;
      if (payload != null && expected != null) {
        final actual = sha256
            .convert(utf8.encode(jsonEncode(payload)))
            .toString();
        if (actual != expected) {
          throw StateError(
            'global_store_checksum_failure:${row['bucket']}:${row['key']}',
          );
        }
      }
    }
  }

  void close() => _db.close();
}
