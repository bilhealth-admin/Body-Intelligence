import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/persistence/sqlite_cloud_platform_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists outbox, inbox, cursors, tombstones and idempotency', () async {
    final store = SqliteCloudPlatformStore.inMemory();
    await store.initialize();
    final record = CloudRecordEnvelope(
      entityKind: CloudEntityKind.weight,
      recordId: 'w1',
      ownerId: 'owner',
      revision: CloudRevision(deviceId: 'd1', sequence: 1),
      updatedAt: DateTime.utc(2026, 7, 24),
      payload: const {'kg': 95.0},
    );
    await store.saveOperation(
      CloudSyncOperation(
        operationId: 'op1',
        mutation: CloudMutationKind.upsert,
        record: record,
        createdAt: DateTime.utc(2026, 7, 24),
      ),
    );
    await store.saveInboxRecord(record);
    await store.saveCursor('owner', 'd1', 'cursor-1');
    expect(await store.pendingCount(), 1);
    expect((await store.readInboxRecord(record.stableKey))?.recordId, 'w1');
    expect(await store.readCursor('owner', 'd1'), 'cursor-1');
    await store.close();
  });
}
