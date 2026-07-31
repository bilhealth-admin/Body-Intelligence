import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_identity_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_platform_policy.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/offline_first_cloud_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline mode preserves local authority and pending outbox', () async {
    final store = _Store();
    final platform = _platform(store: store, online: false);
    await platform.enqueue(record: _record(), consent: _consent());

    final report = await platform.synchronize(
      consent: _consent(),
      device: _device(),
      session: _session(),
    );

    expect(report.availability, CloudPlatformAvailability.localOnly);
    expect(report.pending, 1);
    expect(store.transportCalls, 0);
  });

  test(
    'selective sync blocks excluded AI data before outbox mutation',
    () async {
      final store = _Store();
      final record = _record(kind: CloudEntityKind.intelligenceOutput);

      expect(
        () => _platform(
          store: store,
        ).enqueue(record: record, consent: _consent()),
        throwsStateError,
      );
      expect(store.operations, isEmpty);
    },
  );

  test(
    'successful sync encrypts push and applies decrypted remote delta',
    () async {
      final store = _Store();
      final remote = _record(
        recordId: 'remote',
        updatedAt: DateTime.utc(2026, 7, 24, 2),
      );
      store.remote = CloudRecordEnvelope(
        entityKind: remote.entityKind,
        recordId: remote.recordId,
        ownerId: remote.ownerId,
        revision: remote.revision,
        updatedAt: remote.updatedAt,
        payload: const {'cipher': '95.0'},
      );
      final platform = _platform(store: store);
      await platform.enqueue(record: _record(), consent: _consent());

      final report = await platform.synchronize(
        consent: _consent(),
        device: _device(),
        session: _session(),
      );

      expect(report.pushed, 1);
      expect(report.pulled, 1);
      expect(store.records['weight:remote']?.payload['weight'], 95.0);
      expect(store.operations, isEmpty);
      expect(store.cursor, 'cursor-1');
    },
  );
}

OfflineFirstCloudPlatform _platform({
  required _Store store,
  bool online = true,
}) => OfflineFirstCloudPlatform(
  localStore: store,
  transport: store,
  cipher: const _Cipher(),
  connectivity: _Connectivity(online),
  clock: const _Clock(),
  policy: const CloudPlatformPolicy(maxBatchSize: 10),
);

CloudPrivacyConsent _consent() => CloudPrivacyConsent(
  ownerId: 'owner',
  policy: CloudSelectiveSyncPolicy(
    enabledKinds: const [CloudEntityKind.weight],
  ),
  grantedAt: DateTime.utc(2026, 7, 24),
);
CloudDeviceRegistration _device() => CloudDeviceRegistration(
  deviceId: 'device',
  ownerId: 'owner',
  displayName: 'Phone',
  registeredAt: DateTime.utc(2026, 7, 24),
);
CloudSession _session() => CloudSession(
  sessionId: 'session',
  ownerId: 'owner',
  deviceId: 'device',
  issuedAt: DateTime.utc(2026, 7, 24),
  expiresAt: DateTime.utc(2026, 7, 25),
);
CloudRecordEnvelope _record({
  CloudEntityKind kind = CloudEntityKind.weight,
  String recordId = 'local',
  DateTime? updatedAt,
}) => CloudRecordEnvelope(
  entityKind: kind,
  recordId: recordId,
  ownerId: 'owner',
  revision: CloudRevision(deviceId: 'device', sequence: 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 7, 24, 1),
  payload: const {'weight': 95.0},
);

final class _Clock implements CloudClock {
  const _Clock();
  @override
  DateTime now() => DateTime.utc(2026, 7, 24, 3);
}

final class _Connectivity implements CloudConnectivity {
  const _Connectivity(this.isOnline);
  @override
  final bool isOnline;
}

final class _Cipher implements CloudPayloadCipher {
  const _Cipher();
  @override
  bool get isAvailable => true;
  @override
  Map<String, Object?> encrypt(Map<String, Object?> cleartext) => {
    'cipher': cleartext['weight'].toString(),
  };
  @override
  Map<String, Object?> decrypt(Map<String, Object?> ciphertext) => {
    'weight': double.parse(ciphertext['cipher']! as String),
  };
}

final class _Store implements CloudLocalStore, CloudTransport {
  final operations = <CloudSyncOperation>[];
  final records = <String, CloudRecordEnvelope>{};
  CloudRecordEnvelope? remote;
  String? cursor;
  int transportCalls = 0;
  @override
  Future<void> acknowledgeOperations(Iterable<String> ids) async {
    operations.removeWhere((o) => ids.contains(o.operationId));
  }

  @override
  Future<void> applyRemoteRecord(CloudRecordEnvelope record) async {
    records[record.stableKey] = record;
  }

  @override
  Future<int> pendingCount() async => operations.length;
  @override
  Future<List<CloudSyncOperation>> readPendingOperations({
    required int limit,
  }) async => operations.take(limit).toList();
  @override
  Future<CloudRecordEnvelope?> readRecord(String stableKey) async =>
      records[stableKey];
  @override
  Future<String?> readCursor() async => cursor;
  @override
  Future<void> saveCursor(String? value) async {
    cursor = value;
  }

  @override
  Future<void> saveOperation(CloudSyncOperation operation) async {
    operations.add(operation);
  }

  @override
  Future<CloudSyncBatchResult> synchronize({
    required String ownerId,
    required String deviceId,
    required CloudSession session,
    required List<CloudSyncOperation> operations,
    required String? cursor,
  }) async {
    transportCalls++;
    return CloudSyncBatchResult(
      acknowledgedOperationIds: operations.map((e) => e.operationId),
      remoteRecords: remote == null ? const [] : [remote!],
      serverCursor: 'cursor-1',
    );
  }
}
