import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_identity_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_platform_policy.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/persistence/sqlite_cloud_platform_store.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/durable_offline_first_cloud_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retries durably and resumes after runtime restart', () async {
    final store = SqliteCloudPlatformStore.inMemory();
    await store.initialize();
    final clock = _Clock(DateTime.utc(2026, 7, 24));
    final runtime = DurableOfflineFirstCloudPlatform(
      store: store,
      transport: _FailingTransport(),
      cipher: _Cipher(),
      connectivity: _Connectivity(true),
      clock: clock,
      policy: const CloudPlatformPolicy(
        retry: CloudRetryPolicy(
          initialDelay: Duration.zero,
          maximumDelay: Duration.zero,
          maximumAttempts: 2,
        ),
      ),
    );
    final consent = CloudPrivacyConsent(
      ownerId: 'o',
      policy: CloudSelectiveSyncPolicy(
        enabledKinds: const {CloudEntityKind.weight},
      ),
      grantedAt: clock.now(),
    );
    final record = CloudRecordEnvelope(
      entityKind: CloudEntityKind.weight,
      recordId: '1',
      ownerId: 'o',
      revision: CloudRevision(deviceId: 'd', sequence: 1),
      updatedAt: clock.now(),
      payload: const {'kg': 95},
    );
    await runtime.enqueue(record: record, consent: consent);
    final device = CloudDeviceRegistration(
      deviceId: 'd',
      ownerId: 'o',
      displayName: 'phone',
      registeredAt: clock.now(),
    );
    final session = CloudSession(
      sessionId: 's',
      ownerId: 'o',
      deviceId: 'd',
      issuedAt: clock.now(),
      expiresAt: clock.now().add(const Duration(days: 1)),
    );
    await runtime.synchronize(
      consent: consent,
      device: device,
      session: session,
    );
    expect(await store.pendingCount(), 1);
    final resumed = DurableOfflineFirstCloudPlatform(
      store: store,
      transport: _SuccessTransport(),
      cipher: _Cipher(),
      connectivity: _Connectivity(true),
      clock: clock,
      policy: const CloudPlatformPolicy(
        retry: CloudRetryPolicy(
          initialDelay: Duration.zero,
          maximumDelay: Duration.zero,
          maximumAttempts: 2,
        ),
      ),
    );
    final report = await resumed.synchronize(
      consent: consent,
      device: device,
      session: session,
    );
    expect(report.pushed, 1);
    expect(await store.pendingCount(), 0);
  });
}

final class _Clock implements CloudClock {
  _Clock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}

final class _Connectivity implements CloudConnectivity {
  _Connectivity(this.isOnline);
  @override
  final bool isOnline;
}

final class _Cipher implements CloudPayloadCipher {
  @override
  bool get isAvailable => true;
  @override
  Future<Map<String, Object?>> decrypt(Map<String, Object?> ciphertext) async =>
      ciphertext;
  @override
  Future<Map<String, Object?>> encrypt(Map<String, Object?> cleartext) async =>
      cleartext;
}

final class _FailingTransport implements CloudTransport {
  @override
  Future<CloudSyncBatchResult> synchronize({
    required String ownerId,
    required String deviceId,
    required CloudSession session,
    required List<CloudSyncOperation> operations,
    required String? cursor,
  }) => throw StateError('network');
}

final class _SuccessTransport implements CloudTransport {
  @override
  Future<CloudSyncBatchResult> synchronize({
    required String ownerId,
    required String deviceId,
    required CloudSession session,
    required List<CloudSyncOperation> operations,
    required String? cursor,
  }) async => CloudSyncBatchResult(
    acknowledgedOperationIds: operations.map((e) => e.operationId),
    remoteRecords: const [],
    serverCursor: 'next',
  );
}
