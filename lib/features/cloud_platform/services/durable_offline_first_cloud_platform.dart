import 'dart:convert';

import '../domain/cloud_identity_models.dart';
import '../domain/cloud_operational_models.dart';
import '../domain/cloud_platform_policy.dart';
import '../domain/cloud_sync_models.dart';
import 'cloud_conflict_resolver.dart';
import 'cloud_durable_ports.dart';
import 'cloud_platform_ports.dart';

final class DurableOfflineFirstCloudPlatform {
  const DurableOfflineFirstCloudPlatform({
    required this.store,
    required this.transport,
    required this.cipher,
    required this.connectivity,
    required this.clock,
    required this.policy,
    this.conflictResolver = const CloudConflictResolver(),
    this.failureInjector = const NoopCloudFailureInjector(),
  });
  final DurableCloudStore store;
  final CloudTransport transport;
  final CloudPayloadCipher cipher;
  final CloudConnectivity connectivity;
  final CloudClock clock;
  final CloudPlatformPolicy policy;
  final CloudConflictResolver conflictResolver;
  final CloudFailureInjector failureInjector;

  Future<void> enqueue({
    required CloudRecordEnvelope record,
    required CloudPrivacyConsent consent,
  }) async {
    if (!consent.isActive ||
        consent.ownerId != record.ownerId ||
        !consent.policy.allows(record.entityKind)) {
      throw StateError('Active matching selective consent is required.');
    }
    if (policy.requireEncryption && !cipher.isAvailable) {
      throw StateError('Encryption is required.');
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
    final id = '${record.stableKey}:${record.revision.token}';
    if (await store.hasIdempotencyKey(id)) {
      return;
    }
    await store.saveOperation(
      CloudSyncOperation(
        operationId: id,
        mutation: record.isTombstone
            ? CloudMutationKind.delete
            : CloudMutationKind.upsert,
        record: protected,
        createdAt: clock.now(),
      ),
    );
    await store.saveIdempotencyReceipt(
      CloudIdempotencyReceipt(
        key: id,
        payloadDigest: _digest(jsonEncode(protected.payload)),
        recordedAt: clock.now(),
      ),
    );
  }

  Future<CloudSyncReport> synchronize({
    required CloudPrivacyConsent consent,
    required CloudDeviceRegistration device,
    required CloudSession session,
  }) async {
    final started = clock.now();
    if (!consent.isActive || !device.active) {
      return _report(started, CloudPlatformAvailability.revoked, [
        'Consent or device trust is revoked.',
      ]);
    }
    if (consent.ownerId != device.ownerId ||
        consent.ownerId != session.ownerId) {
      return _report(started, CloudPlatformAvailability.revoked, [
        'Cloud owner identity mismatch.',
      ], ownerId: consent.ownerId);
    }
    if (!session.isUsableAt(started) || session.deviceId != device.deviceId) {
      return _report(started, CloudPlatformAvailability.paused, [
        'Authenticated session unavailable.',
      ]);
    }
    if (!connectivity.isOnline) {
      return _report(started, CloudPlatformAvailability.localOnly, [
        'Offline; durable outbox preserved.',
      ]);
    }
    final pending = await store.readReadyOperations(
      ownerId: consent.ownerId,
      now: started,
      limit: policy.maxBatchSize,
    );
    try {
      failureInjector.checkpoint('before-transport');
      final batch = await transport.synchronize(
        ownerId: consent.ownerId,
        deviceId: device.deviceId,
        session: session,
        operations: pending,
        cursor: await store.readCursor(consent.ownerId, device.deviceId),
      );
      final pendingIds = pending.map((value) => value.operationId).toSet();
      if (!batch.acknowledgedOperationIds.every(pendingIds.contains)) {
        throw const FormatException(
          'Cloud acknowledged an operation outside the submitted batch.',
        );
      }
      if (!batch.remoteRecords.every(
        (record) => record.ownerId == consent.ownerId,
      )) {
        throw const FormatException('Cross-account cloud record rejected.');
      }
      failureInjector.checkpoint('after-transport');
      await store.acknowledgeOperations(batch.acknowledgedOperationIds);
      var applied = 0;
      var conflicts = 0;
      for (final encrypted in batch.remoteRecords) {
        final remote = CloudRecordEnvelope(
          entityKind: encrypted.entityKind,
          recordId: encrypted.recordId,
          ownerId: encrypted.ownerId,
          revision: encrypted.revision,
          updatedAt: encrypted.updatedAt,
          deletedAt: encrypted.deletedAt,
          schemaVersion: encrypted.schemaVersion,
          payload: await cipher.decrypt(encrypted.payload),
        );
        final local = await store.readInboxRecord(remote.stableKey);
        if (local == null) {
          await store.saveInboxRecord(remote);
          if (remote.isTombstone) {
            await store.saveTombstone(remote);
          }
          applied++;
        } else {
          final conflict = conflictResolver.resolve(
            local: local,
            remote: remote,
          );
          conflicts++;
          await store.saveConflict(
            CloudConflictRecord(
              conflictId: '${remote.stableKey}:${remote.revision.token}',
              stableKey: remote.stableKey,
              reason: conflict.reason,
              resolution: conflict.resolution,
              createdAt: clock.now(),
            ),
          );
          if (conflict.merged != null) {
            await store.saveInboxRecord(conflict.merged!);
          }
        }
      }
      await store.saveCursor(
        consent.ownerId,
        device.deviceId,
        batch.serverCursor,
      );
      return CloudSyncReport(
        startedAt: started,
        completedAt: clock.now(),
        pushed: batch.acknowledgedOperationIds.length,
        pulled: applied,
        conflicts: conflicts,
        pending: await store.pendingCount(ownerId: consent.ownerId),
        availability: CloudPlatformAvailability.ready,
        diagnostics: const [],
      );
    } catch (error) {
      for (final op in pending) {
        final attempt = op.attempt + 1;
        if (attempt >= policy.retry.maximumAttempts) {
          await store.moveToDeadLetter(
            CloudDeadLetter(
              operationId: op.operationId,
              reason: '$error',
              attempts: attempt,
              failedAt: clock.now(),
            ),
          );
        } else {
          await store.markRetry(
            op.copyWith(
              attempt: attempt,
              disposition: CloudSyncDisposition.retry,
              lastError: '$error',
            ),
            clock.now().add(policy.retry.delayForAttempt(attempt)),
          );
        }
      }
      return _report(started, CloudPlatformAvailability.paused, [
        'Synchronization failed; durable retry scheduled.',
      ], ownerId: consent.ownerId);
    }
  }

  Future<CloudSyncReport> _report(
    DateTime started,
    CloudPlatformAvailability availability,
    List<String> diagnostics, {
    String? ownerId,
  }) async => CloudSyncReport(
    startedAt: started,
    completedAt: clock.now(),
    pushed: 0,
    pulled: 0,
    conflicts: await store.conflictCount(),
    pending: await store.pendingCount(ownerId: ownerId),
    availability: availability,
    diagnostics: diagnostics,
  );
  static String _digest(String value) => base64Url.encode(utf8.encode(value));
}
