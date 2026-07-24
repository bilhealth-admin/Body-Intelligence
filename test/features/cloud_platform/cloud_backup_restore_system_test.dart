import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/persistence/sqlite_cloud_platform_store.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_backup_restore_engine.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_durable_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup restore verifies and rolls back on injected failure', () async {
    final store = SqliteCloudPlatformStore.inMemory();
    await store.initialize();
    final record = CloudRecordEnvelope(
      entityKind: CloudEntityKind.profile,
      recordId: 'p',
      ownerId: 'o',
      revision: CloudRevision(deviceId: 'd', sequence: 1),
      updatedAt: DateTime.utc(2026, 7, 24),
      payload: const {'name': 'BIL'},
    );
    await store.saveInboxRecord(record);
    final engine = CloudBackupRestoreEngine(store: store, cipher: _Cipher());
    final backup = await engine.createBackup(
      ownerId: 'o',
      schemaVersion: 1,
      createdAt: DateTime.utc(2026, 7, 24),
    );
    final report = await engine.restore(
      backupId: backup.backupId,
      localSchemaVersion: 1,
      failureInjector: const NoopCloudFailureInjector(),
    );
    expect(report.restoredRecords, 1);
    final rolledBack = await engine.restore(
      backupId: backup.backupId,
      localSchemaVersion: 1,
      failureInjector: _Failure(),
    );
    expect(rolledBack.status.name, 'rolledBack');
  });
}

final class _Cipher implements CloudPayloadCipher {
  @override
  bool get isAvailable => true;
  @override
  Map<String, Object?> decrypt(Map<String, Object?> ciphertext) => ciphertext;
  @override
  Map<String, Object?> encrypt(Map<String, Object?> cleartext) => cleartext;
}

final class _Failure implements CloudFailureInjector {
  @override
  void checkpoint(String name) {
    if (name == 'after-restore-apply') throw StateError('injected');
  }
}
