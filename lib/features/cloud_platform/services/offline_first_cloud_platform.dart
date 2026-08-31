import '../domain/cloud_identity_models.dart';
import '../domain/cloud_platform_policy.dart';
import '../domain/cloud_sync_models.dart';
import 'cloud_conflict_resolver.dart';
import 'cloud_platform_ports.dart';

final class OfflineFirstCloudPlatform {
  const OfflineFirstCloudPlatform({
    required this.localStore,
    required this.transport,
    required this.cipher,
    required this.connectivity,
    required this.clock,
    required this.policy,
    this.conflictResolver = const CloudConflictResolver(),
  });

  final CloudLocalStore localStore;
  final CloudTransport transport;
  final CloudPayloadCipher cipher;
  final CloudConnectivity connectivity;
  final CloudClock clock;
  final CloudPlatformPolicy policy;
  final CloudConflictResolver conflictResolver;

  Future<void> enqueue({
    required CloudRecordEnvelope record,
    required CloudPrivacyConsent consent,
  }) async {
    if (!consent.isActive || consent.ownerId != record.ownerId) {
      throw StateError('Active owner-scoped cloud consent is required.');
    }
    if (!consent.policy.allows(record.entityKind)) {
      throw StateError(
        'Selective-sync policy excludes ${record.entityKind.name}.',
      );
    }
    if (policy.requireEncryption && !cipher.isAvailable) {
      throw StateError(
        'Encryption capability is required before cloud enqueue.',
      );
    }

    final protected = CloudRecordEnvelope(
      entityKind: record.entityKind,
      recordId: record.recordId,
      ownerId: record.ownerId,
      revision: record.revision,
      updatedAt: record.updatedAt,
      deletedAt: record.deletedAt,
      schemaVersion: record.schemaVersion,
      payload: await cipher.encrypt(record.payload),
    );
    await localStore.saveOperation(
      CloudSyncOperation(
        operationId: '${record.stableKey}:${record.revision.token}',
        mutation: record.isTombstone
            ? CloudMutationKind.delete
            : CloudMutationKind.upsert,
        record: protected,
        createdAt: clock.now(),
      ),
    );
  }

  Future<CloudSyncReport> synchronize({
    required CloudPrivacyConsent consent,
    required CloudDeviceRegistration device,
    required CloudSession session,
  }) async {
    final started = clock.now();
    final diagnostics = <String>[];

    if (!consent.isActive) {
      return _report(
        started,
        CloudPlatformAvailability.revoked,
        diagnostics..add('Cloud consent is revoked.'),
      );
    }
    if (!device.active || device.ownerId != consent.ownerId) {
      return _report(
        started,
        CloudPlatformAvailability.revoked,
        diagnostics..add('Device registration is unavailable.'),
      );
    }
    if (!session.isUsableAt(started) || session.deviceId != device.deviceId) {
      return _report(
        started,
        CloudPlatformAvailability.paused,
        diagnostics..add('Authenticated device session is unavailable.'),
      );
    }
    if (!connectivity.isOnline) {
      return _report(
        started,
        CloudPlatformAvailability.localOnly,
        diagnostics..add('Offline: local database remains authoritative.'),
      );
    }
    if (policy.requireEncryption && !cipher.isAvailable) {
      return _report(
        started,
        CloudPlatformAvailability.paused,
        diagnostics..add('Encryption boundary is unavailable.'),
      );
    }

    final pending = await localStore.readPendingOperations(
      limit: policy.maxBatchSize,
    );
    final batch = await transport.synchronize(
      ownerId: consent.ownerId,
      deviceId: device.deviceId,
      session: session,
      operations: pending,
      cursor: await localStore.readCursor(),
    );
    await localStore.acknowledgeOperations(batch.acknowledgedOperationIds);

    var conflicts = 0;
    var applied = 0;
    for (final encryptedRemote in batch.remoteRecords) {
      if (encryptedRemote.ownerId != consent.ownerId ||
          !consent.policy.allows(encryptedRemote.entityKind)) {
        diagnostics.add(
          'Rejected out-of-scope remote record ${encryptedRemote.stableKey}.',
        );
        continue;
      }
      final remote = CloudRecordEnvelope(
        entityKind: encryptedRemote.entityKind,
        recordId: encryptedRemote.recordId,
        ownerId: encryptedRemote.ownerId,
        revision: encryptedRemote.revision,
        updatedAt: encryptedRemote.updatedAt,
        deletedAt: encryptedRemote.deletedAt,
        schemaVersion: encryptedRemote.schemaVersion,
        payload: await cipher.decrypt(encryptedRemote.payload),
      );
      final local = await localStore.readRecord(remote.stableKey);
      if (local == null) {
        await localStore.applyRemoteRecord(remote);
        applied++;
        continue;
      }
      final conflict = conflictResolver.resolve(local: local, remote: remote);
      conflicts++;
      final resolved = conflict.merged;
      if (resolved != null && !identical(resolved, local)) {
        await localStore.applyRemoteRecord(resolved);
        applied++;
      }
      diagnostics.add('${remote.stableKey}: ${conflict.reason}');
    }
    await localStore.saveCursor(batch.serverCursor);

    return CloudSyncReport(
      startedAt: started,
      completedAt: clock.now(),
      pushed: batch.acknowledgedOperationIds.length,
      pulled: applied,
      conflicts: conflicts,
      pending: await localStore.pendingCount(),
      availability: CloudPlatformAvailability.ready,
      diagnostics: diagnostics,
    );
  }

  Future<CloudSyncReport> _report(
    DateTime started,
    CloudPlatformAvailability availability,
    List<String> diagnostics,
  ) async => CloudSyncReport(
    startedAt: started,
    completedAt: clock.now(),
    pushed: 0,
    pulled: 0,
    conflicts: 0,
    pending: await localStore.pendingCount(),
    availability: availability,
    diagnostics: diagnostics,
  );
}
