import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_identity_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_platform_policy.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/persistence/sqlite_cloud_platform_store.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/durable_offline_first_cloud_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('durable cloud account isolation', () {
    late SqliteCloudPlatformStore store;
    const ownerA = 'owner-a';
    const ownerB = 'owner-b';
    const deviceA = 'device-a';
    final now = DateTime.utc(2026, 8, 10, 12);

    setUp(() async {
      store = SqliteCloudPlatformStore.inMemory();
      await store.initialize();
    });

    tearDown(() => store.close());

    test('producer -> transport -> consumer preserves tombstone', () async {
      final remoteTombstone = _record(
        ownerId: ownerA,
        deviceId: 'device-remote',
        sequence: 4,
        deletedAt: now,
      );
      final transport = _Transport(remoteRecords: [remoteTombstone]);
      final engine = _engine(store, transport, now);
      final produced = _record(ownerId: ownerA, deviceId: deviceA, sequence: 1);

      await engine.enqueue(record: produced, consent: _consent(ownerA, now));
      final report = await engine.synchronize(
        consent: _consent(ownerA, now),
        device: _device(ownerA, deviceA, now),
        session: _session(ownerA, deviceA, now),
      );

      expect(transport.submitted.single.record.ownerId, ownerA);
      expect(report.pushed, 1);
      expect(report.pulled, 1);
      expect(await store.pendingCount(ownerId: ownerA), 0);
      final consumed = await store.readAllRecords(ownerA);
      expect(consumed.single.isTombstone, isTrue);
      expect(
        (await store.readTombstones(ownerA)).single.stableKey,
        remoteTombstone.stableKey,
      );
    });

    test('same record id remains isolated across account switching', () async {
      final operationA = _operation(
        _record(ownerId: ownerA, deviceId: deviceA, sequence: 1),
        now,
      );
      final operationB = _operation(
        _record(ownerId: ownerB, deviceId: 'device-b', sequence: 1),
        now,
      );
      await store.saveOperation(operationA);
      await store.saveOperation(operationB);

      final readyA = await store.readReadyOperations(
        ownerId: ownerA,
        now: now,
        limit: 100,
      );
      expect(readyA.map((value) => value.record.ownerId), [ownerA]);
      expect(operationA.record.stableKey, isNot(operationB.record.stableKey));
      expect(await store.pendingCount(ownerId: ownerA), 1);
      expect(await store.pendingCount(ownerId: ownerB), 1);
    });

    test(
      'cross-account remote record fails closed and stays out of inbox',
      () async {
        final transport = _Transport(
          remoteRecords: [
            _record(ownerId: ownerB, deviceId: 'remote-b', sequence: 2),
          ],
        );
        final engine = _engine(store, transport, now);
        await engine.enqueue(
          record: _record(ownerId: ownerA, deviceId: deviceA, sequence: 1),
          consent: _consent(ownerA, now),
        );

        final report = await engine.synchronize(
          consent: _consent(ownerA, now),
          device: _device(ownerA, deviceA, now),
          session: _session(ownerA, deviceA, now),
        );

        expect(report.availability, CloudPlatformAvailability.paused);
        expect(await store.readAllRecords(ownerA), isEmpty);
        expect(await store.readAllRecords(ownerB), isEmpty);
        expect(await store.pendingCount(ownerId: ownerA), 1);
      },
    );

    test('mismatched session never calls transport', () async {
      final transport = _Transport();
      final engine = _engine(store, transport, now);
      final report = await engine.synchronize(
        consent: _consent(ownerA, now),
        device: _device(ownerA, deviceA, now),
        session: _session(ownerB, deviceA, now),
      );
      expect(report.availability, CloudPlatformAvailability.revoked);
      expect(transport.calls, 0);
    });
  });
}

DurableOfflineFirstCloudPlatform _engine(
  SqliteCloudPlatformStore store,
  CloudTransport transport,
  DateTime now,
) => DurableOfflineFirstCloudPlatform(
  store: store,
  transport: transport,
  cipher: const _Cipher(),
  connectivity: const _Connectivity(),
  clock: _Clock(now),
  policy: const CloudPlatformPolicy(),
);

CloudPrivacyConsent _consent(String owner, DateTime now) => CloudPrivacyConsent(
  ownerId: owner,
  policy: CloudSelectiveSyncPolicy(
    enabledKinds: const [CloudEntityKind.weight],
  ),
  grantedAt: now,
);

CloudDeviceRegistration _device(String owner, String device, DateTime now) =>
    CloudDeviceRegistration(
      deviceId: device,
      ownerId: owner,
      displayName: 'Test device',
      registeredAt: now,
    );

CloudSession _session(String owner, String device, DateTime now) =>
    CloudSession(
      sessionId: 'session-$owner',
      ownerId: owner,
      deviceId: device,
      issuedAt: now.subtract(const Duration(minutes: 1)),
      expiresAt: now.add(const Duration(hours: 1)),
    );

CloudRecordEnvelope _record({
  required String ownerId,
  required String deviceId,
  required int sequence,
  DateTime? deletedAt,
}) => CloudRecordEnvelope(
  entityKind: CloudEntityKind.weight,
  recordId: 'shared-record-id',
  ownerId: ownerId,
  revision: CloudRevision(deviceId: deviceId, sequence: sequence),
  updatedAt: DateTime.utc(2026, 8, 10, 12),
  deletedAt: deletedAt,
  payload: deletedAt == null ? const {'kg': 80.0} : const {},
);

CloudSyncOperation _operation(CloudRecordEnvelope record, DateTime now) =>
    CloudSyncOperation(
      operationId: '${record.stableKey}:${record.revision.token}',
      mutation: record.isTombstone
          ? CloudMutationKind.delete
          : CloudMutationKind.upsert,
      record: record,
      createdAt: now,
    );

final class _Transport implements CloudTransport {
  _Transport({this.remoteRecords = const []});
  final List<CloudRecordEnvelope> remoteRecords;
  final List<CloudSyncOperation> submitted = [];
  int calls = 0;

  @override
  Future<CloudSyncBatchResult> synchronize({
    required String ownerId,
    required String deviceId,
    required CloudSession session,
    required List<CloudSyncOperation> operations,
    required String? cursor,
  }) async {
    calls++;
    submitted.addAll(operations);
    return CloudSyncBatchResult(
      acknowledgedOperationIds: operations.map(
        (operation) => operation.operationId,
      ),
      remoteRecords: remoteRecords,
      serverCursor: '1',
    );
  }
}

final class _Cipher implements CloudPayloadCipher {
  const _Cipher();
  @override
  bool get isAvailable => true;
  @override
  Future<Map<String, Object?>> decrypt(Map<String, Object?> ciphertext) async =>
      ciphertext;
  @override
  Future<Map<String, Object?>> encrypt(Map<String, Object?> cleartext) async =>
      cleartext;
}

final class _Connectivity implements CloudConnectivity {
  const _Connectivity();
  @override
  bool get isOnline => true;
}

final class _Clock implements CloudClock {
  const _Clock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}
