import 'dart:convert';

import '../domain/cloud_operational_models.dart';
import '../domain/cloud_sync_models.dart';
import 'cloud_durable_ports.dart';
import 'cloud_platform_ports.dart';
import 'cloud_schema_negotiator.dart';

final class CloudBackupRestoreEngine {
  const CloudBackupRestoreEngine({
    required this.store,
    required this.cipher,
    this.negotiator = const CloudSchemaNegotiator(),
  });
  final DurableCloudStore store;
  final CloudPayloadCipher cipher;
  final CloudSchemaNegotiator negotiator;

  Future<CloudBackupArtifact> createBackup({
    required String ownerId,
    required int schemaVersion,
    required DateTime createdAt,
  }) async {
    final records = await store.readAllRecords(ownerId);
    final clear = {
      'ownerId': ownerId,
      'schemaVersion': schemaVersion,
      'records': records.map(_recordToJson).toList(),
    };
    final canonical = jsonEncode(clear);
    final backup = CloudBackupArtifact(
      backupId: 'backup-$ownerId-${createdAt.toUtc().microsecondsSinceEpoch}',
      ownerId: ownerId,
      schemaVersion: schemaVersion,
      checksum: _digest(canonical),
      encryptedPayload: cipher.encrypt(clear),
      createdAt: createdAt,
    );
    await store.saveBackup(backup);
    return backup;
  }

  Future<CloudRestoreReport> restore({
    required String backupId,
    required int localSchemaVersion,
    required CloudFailureInjector failureInjector,
  }) async {
    final backup = await store.readBackup(backupId);
    if (backup == null) {
      return CloudRestoreReport(
        backupId: backupId,
        status: CloudRestoreStatus.rejected,
        restoredRecords: 0,
        diagnostics: const ['Backup not found.'],
      );
    }
    final agreement = negotiator.negotiate(
      localVersion: localSchemaVersion,
      remoteVersion: backup.schemaVersion,
    );
    if (!agreement.compatible) {
      return CloudRestoreReport(
        backupId: backupId,
        status: CloudRestoreStatus.rejected,
        restoredRecords: 0,
        diagnostics: const ['Schema versions are incompatible.'],
      );
    }
    final clear = cipher.decrypt(backup.encryptedPayload);
    final canonical = jsonEncode(clear);
    if (_digest(canonical) != backup.checksum) {
      return CloudRestoreReport(
        backupId: backupId,
        status: CloudRestoreStatus.rejected,
        restoredRecords: 0,
        diagnostics: const ['Checksum verification failed.'],
      );
    }
    final ownerId = clear['ownerId']! as String;
    final previous = await store.readAllRecords(ownerId);
    final records = ((clear['records']! as List).cast<Map>())
        .map((e) => _recordFromJson(e.cast<String, Object?>()))
        .toList();
    try {
      failureInjector.checkpoint('before-restore-apply');
      await store.replaceOwnerRecords(ownerId, records);
      failureInjector.checkpoint('after-restore-apply');
      return CloudRestoreReport(
        backupId: backupId,
        status: CloudRestoreStatus.applied,
        restoredRecords: records.length,
        diagnostics: const ['Backup verified and applied.'],
      );
    } catch (_) {
      await store.replaceOwnerRecords(ownerId, previous);
      return CloudRestoreReport(
        backupId: backupId,
        status: CloudRestoreStatus.rolledBack,
        restoredRecords: 0,
        diagnostics: const ['Restore failed and was rolled back.'],
      );
    }
  }

  Future<CloudExportArtifact> exportOwner({
    required String ownerId,
    required DateTime createdAt,
  }) async {
    final records = await store.readAllRecords(ownerId);
    final payload = {
      'ownerId': ownerId,
      'records': records.map(_recordToJson).toList(),
    };
    return CloudExportArtifact(
      ownerId: ownerId,
      format: 'application/json',
      checksum: _digest(jsonEncode(payload)),
      payload: payload,
      createdAt: createdAt,
    );
  }

  static String _digest(String value) {
    var hash = 2166136261;
    for (final unit in utf8.encode(value)) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Map<String, Object?> _recordToJson(CloudRecordEnvelope r) => {
    'entityKind': r.entityKind.name,
    'recordId': r.recordId,
    'ownerId': r.ownerId,
    'deviceId': r.revision.deviceId,
    'sequence': r.revision.sequence,
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
        revision: CloudRevision(
          deviceId: j['deviceId']! as String,
          sequence: j['sequence']! as int,
        ),
        updatedAt: DateTime.parse(j['updatedAt']! as String),
        deletedAt: j['deletedAt'] == null
            ? null
            : DateTime.parse(j['deletedAt']! as String),
        schemaVersion: j['schemaVersion']! as int,
        payload: (j['payload']! as Map).cast<String, Object?>(),
      );
}
