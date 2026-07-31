import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../core/global_platform_core.dart';
import 'global_platform_sqlite_store.dart';

final class GlobalStoreEnvelope {
  const GlobalStoreEnvelope({
    required this.version,
    required this.revision,
    required this.updatedAt,
    required this.payload,
    required this.checksum,
  });

  final int version;
  final int revision;
  final String updatedAt;
  final String checksum;
  final Map<String, Object?> payload;
}

final class GlobalTypedRepository {
  GlobalTypedRepository({
    required this.store,
    required this.bucket,
    required this.schemaVersion,
    this.largePayloadLimitBytes = 1048576,
  });

  final GlobalDurableStore store;
  final String bucket;
  final int schemaVersion;
  final int largePayloadLimitBytes;

  Future<GlobalStoreEnvelope?> read(String key) async {
    final row = await store.get(bucket, key);
    if (row == null) {
      return null;
    }
    final payload = Map<String, Object?>.from(row['payload'] as Map);
    final checksum = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();
    if (checksum != row['checksum']) {
      throw StateError('global_store_corruption:$bucket:$key');
    }
    final version = row['version'] as int;
    if (version > schemaVersion) {
      throw StateError('unsupported_future_schema:$version');
    }
    return GlobalStoreEnvelope(
      version: version,
      revision: row['revision'] as int,
      updatedAt: row['updatedAt'] as String,
      payload: payload,
      checksum: checksum,
    );
  }

  Future<GlobalStoreEnvelope> upsert(
    String key,
    Map<String, Object?> payload, {
    int? expectedRevision,
  }) async {
    final bytes = utf8.encode(jsonEncode(payload));
    if (bytes.length > largePayloadLimitBytes) {
      throw StateError('payload_limit_exceeded');
    }
    final current = await read(key);
    if (expectedRevision != null && current?.revision != expectedRevision) {
      throw StateError('optimistic_concurrency_conflict');
    }
    final revision = (current?.revision ?? 0) + 1;
    final checksum = sha256.convert(bytes).toString();
    final row = <String, Object?>{
      'version': schemaVersion,
      'revision': revision,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'payload': Map<String, Object?>.unmodifiable(payload),
      'checksum': checksum,
    };
    if (expectedRevision != null && store is SqliteGlobalPlatformStore) {
      await (store as SqliteGlobalPlatformStore).compareAndSwap(
        bucket: bucket,
        key: key,
        expectedRevision: expectedRevision,
        nextValue: row,
      );
    } else {
      await store.put(bucket, key, row);
    }
    return (await read(key))!;
  }

  Future<void> migrate(
    int fromVersion,
    Map<int, Map<String, Object?> Function(Map<String, Object?>)> migrations,
  ) async {
    if (fromVersion > schemaVersion) {
      throw StateError('migration_from_future_schema');
    }
    final rows = await store.list(bucket);
    for (final row in rows) {
      var payload = Map<String, Object?>.from(row['payload'] as Map);
      var version = row['version'] as int;
      while (version < schemaVersion) {
        final migration = migrations[version];
        if (migration == null) {
          throw StateError('missing_migration:$version');
        }
        payload = migration(payload);
        version++;
      }
      final key = payload['id'] as String?;
      if (key != null) {
        await upsert(key, payload);
      }
    }
  }
}

final class GlobalRetentionPolicy {
  const GlobalRetentionPolicy({required this.maxAge, required this.maxRecords});

  final Duration maxAge;
  final int maxRecords;
}
