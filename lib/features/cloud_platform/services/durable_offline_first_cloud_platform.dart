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
      return _report(
        started,
        CloudPlatformAvailability.paused,
        ['Authenticated session unavailable.'],
        failureCode: 'cloud_sync_session_unavailable',
      );
    }
    if (!connectivity.isOnline) {
      return _report(started, CloudPlatformAvailability.localOnly, [
        'Offline; durable outbox preserved.',
      ]);
    }
    var pending = <CloudSyncOperation>[];
    var stage = 'outbox_read';
    var pushed = 0;
    var applied = 0;
    var conflicts = 0;
    try {
      pending = await store.readReadyOperations(
        ownerId: consent.ownerId,
        now: started,
        limit: policy.maxBatchSize,
      );
      stage = 'cursor_read';
      final cursor = await store.readCursor(consent.ownerId, device.deviceId);
      stage = 'transport';
      failureInjector.checkpoint('before-transport');
      final batch = await transport.synchronize(
        ownerId: consent.ownerId,
        deviceId: device.deviceId,
        session: session,
        operations: pending,
        cursor: cursor,
      );
      stage = 'response_validation';
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
      if (batch.hasMore &&
          (batch.serverCursor == null ||
              batch.serverCursor == cursor ||
              batch.remoteRecords.isEmpty)) {
        throw const FormatException('Cloud page made no durable progress.');
      }
      stage = 'acknowledgement';
      failureInjector.checkpoint('after-transport');
      await store.acknowledgeOperations(batch.acknowledgedOperationIds);
      pushed = batch.acknowledgedOperationIds.length;
      for (final encrypted in batch.remoteRecords) {
        stage = 'decrypt';
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
        stage = 'inbox_read';
        final local = await store.readInboxRecord(remote.stableKey);
        // A previous page may have persisted records before its cursor write
        // failed. Replaying those exact revisions is not a new conflict.
        if (local != null && _sameRecord(local, remote)) {
          if (remote.isTombstone) {
            stage = 'tombstone_write';
            await store.saveTombstone(remote);
          }
          continue;
        }
        if (local == null) {
          stage = 'inbox_write';
          await store.saveInboxRecord(remote);
          if (remote.isTombstone) {
            stage = 'tombstone_write';
            await store.saveTombstone(remote);
          }
          applied++;
        } else {
          final conflict = conflictResolver.resolve(
            local: local,
            remote: remote,
          );
          conflicts++;
          stage = 'conflict_write';
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
            stage = 'inbox_write';
            await store.saveInboxRecord(conflict.merged!);
            if (conflict.merged!.isTombstone) {
              stage = 'tombstone_write';
              await store.saveTombstone(conflict.merged!);
            }
          }
        }
      }
      stage = 'cursor_write';
      await store.saveCursor(
        consent.ownerId,
        device.deviceId,
        batch.serverCursor,
      );
      stage = 'cursor_verify';
      if (await store.readCursor(consent.ownerId, device.deviceId) !=
          batch.serverCursor) {
        throw StateError('Durable cloud cursor verification failed.');
      }
      stage = 'pending_read';
      final remaining = await store.pendingCount(ownerId: consent.ownerId);
      final blocked = (await store.readDeadLetters()).any(
        (entry) => entry.operationId.startsWith('${consent.ownerId}:'),
      );
      return CloudSyncReport(
        startedAt: started,
        completedAt: clock.now(),
        pushed: batch.acknowledgedOperationIds.length,
        pulled: applied,
        conflicts: conflicts,
        pending: remaining,
        availability: batch.hasMore || blocked
            ? CloudPlatformAvailability.paused
            : CloudPlatformAvailability.ready,
        diagnostics: batch.hasMore
            ? const ['More cloud pages remain; durable cursor saved.']
            : const [],
        hasMore: batch.hasMore,
        cursorAdvanced: batch.serverCursor != cursor,
        failureCode: blocked ? 'cloud_sync_dead_letters_pending' : null,
      );
    } catch (error) {
      final failureCode = stage == 'transport' && error is FormatException
          ? 'cloud_sync_response_invalid'
          : 'cloud_sync_${stage}_failed';
      // An inbound/local failure must never resurrect an acknowledged upload,
      // consume its network retry budget, or move it to a dead letter.
      final retryable = stage == 'transport' && error is! FormatException;
      for (final op in retryable ? pending : <CloudSyncOperation>[]) {
        final attempt = op.attempt + 1;
        if (attempt >= policy.retry.maximumAttempts) {
          await store.moveToDeadLetter(
            CloudDeadLetter(
              operationId: op.operationId,
              reason: failureCode,
              attempts: attempt,
              failedAt: clock.now(),
            ),
          );
        } else {
          await store.markRetry(
            op.copyWith(
              attempt: attempt,
              disposition: CloudSyncDisposition.retry,
              lastError: failureCode,
            ),
            clock.now().add(policy.retry.delayForAttempt(attempt)),
          );
        }
      }
      return CloudSyncReport(
        startedAt: started,
        completedAt: clock.now(),
        pushed: pushed,
        pulled: applied,
        conflicts: conflicts,
        pending: await store.pendingCount(ownerId: consent.ownerId),
        availability: CloudPlatformAvailability.paused,
        diagnostics: [failureCode],
        failureCode: failureCode,
      );
    }
  }

  Future<CloudSyncReport> _report(
    DateTime started,
    CloudPlatformAvailability availability,
    List<String> diagnostics, {
    String? ownerId,
    String? failureCode,
  }) async => CloudSyncReport(
    startedAt: started,
    completedAt: clock.now(),
    pushed: 0,
    pulled: 0,
    conflicts: await store.conflictCount(),
    pending: await store.pendingCount(ownerId: ownerId),
    availability: availability,
    diagnostics: diagnostics,
    failureCode: failureCode,
  );
  static bool _sameRecord(CloudRecordEnvelope a, CloudRecordEnvelope b) =>
      a.stableKey == b.stableKey &&
      a.schemaVersion == b.schemaVersion &&
      a.revision.token == b.revision.token &&
      a.updatedAt == b.updatedAt &&
      a.deletedAt == b.deletedAt &&
      _samePayload(a.payload, b.payload);

  static bool _samePayload(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every(
            (key) => b.containsKey(key) && _samePayload(a[key], b[key]),
          );
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          Iterable<int>.generate(
            a.length,
          ).every((index) => _samePayload(a[index], b[index]));
    }
    return a == b;
  }

  static String _digest(String value) => base64Url.encode(utf8.encode(value));
}
