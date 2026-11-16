import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/providers/cloud_manual_sync_status_provider.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/app_database_cloud_inbox_applier.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/app_database_cloud_outbox_producer.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_restore_v2_engine.dart';
import 'package:drift/native.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_identity_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_platform_policy.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/persistence/sqlite_cloud_platform_store.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/durable_offline_first_cloud_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  _classificationMetadataRegressionTests();
  _resolvedConflictOutcomeRegressionTests();
  test('203 queued rows drain in three acknowledged upload batches', () async {
    final store = SqliteCloudPlatformStore.inMemory();
    await store.initialize();
    addTearDown(store.close);
    final clock = _Clock(DateTime.utc(2026, 10, 23));
    final transport = _SuccessTransport();
    final runtime = DurableOfflineFirstCloudPlatform(
      store: store,
      transport: transport,
      cipher: _Cipher(),
      connectivity: _Connectivity(true),
      clock: clock,
      policy: const CloudPlatformPolicy(),
    );
    final consent = CloudPrivacyConsent(
      ownerId: 'o',
      grantedAt: clock.now(),
      policy: CloudSelectiveSyncPolicy(
        enabledKinds: const {CloudEntityKind.weight},
      ),
    );
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
    for (var i = 0; i < 203; i++) {
      await runtime.enqueue(
        consent: consent,
        record: CloudRecordEnvelope(
          entityKind: CloudEntityKind.weight,
          recordId: 'row-$i',
          ownerId: 'o',
          revision: CloudRevision(deviceId: 'd', sequence: 1),
          updatedAt: clock.now(),
          payload: {'kg': 80},
        ),
      );
    }
    var calls = 0;
    final report = await drainCloudSyncPages(() async {
      calls++;
      final page = await runtime.synchronize(
        consent: consent,
        device: device,
        session: session,
      );
      if (calls == 1) {
        expect(page.pending, 103);
        expect(page.hasMore, isFalse);
        expect(page.availability, CloudPlatformAvailability.paused);
        expect(page.completed, isFalse);
      }
      return page;
    });
    expect(calls, 3);
    expect(report.pushed, 203);
    expect(report.pending, 0);
    expect(report.completed, isTrue);
    expect(await store.pendingCount(), 0);
    expect(await store.readDeadLetters(), isEmpty);
  });
  test('persists a partial page cursor and never reports ready', () async {
    final store = SqliteCloudPlatformStore.inMemory();
    await store.initialize();
    final clock = _Clock(DateTime.utc(2026, 7, 24));
    final runtime = DurableOfflineFirstCloudPlatform(
      store: store,
      transport: _PagedTransport(),
      cipher: _Cipher(),
      connectivity: _Connectivity(true),
      clock: clock,
      policy: const CloudPlatformPolicy(),
    );
    final consent = CloudPrivacyConsent(
      ownerId: 'o',
      policy: CloudSelectiveSyncPolicy(
        enabledKinds: const {CloudEntityKind.weight},
      ),
      grantedAt: clock.now(),
    );
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

    final report = await runtime.synchronize(
      consent: consent,
      device: device,
      session: session,
    );

    expect(report.availability, CloudPlatformAvailability.paused);
    expect(report.completed, isFalse);
    expect(await store.readCursor('o', 'd'), '100');
    expect(report.diagnostics, contains(contains('durable cursor saved')));
  });

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

final class _PagedTransport implements CloudTransport {
  @override
  Future<CloudSyncBatchResult> synchronize({
    required String ownerId,
    required String deviceId,
    required CloudSession session,
    required List<CloudSyncOperation> operations,
    required String? cursor,
  }) async => CloudSyncBatchResult(
    acknowledgedOperationIds: operations.map((e) => e.operationId),
    remoteRecords: [
      CloudRecordEnvelope(
        entityKind: CloudEntityKind.weight,
        recordId: 'page-record',
        ownerId: ownerId,
        revision: CloudRevision(deviceId: deviceId, sequence: 1),
        updatedAt: DateTime.utc(2026, 7, 24),
        payload: const {'kg': 95},
      ),
    ],
    serverCursor: '100',
    hasMore: true,
  );
}

void _resolvedConflictOutcomeRegressionTests() {
  test(
    'real V1 automatic winner does not demand unresolved review or block the timestamp',
    () async {
      final store = SqliteCloudPlatformStore.inMemory();
      await store.initialize();
      addTearDown(store.close);
      final now = DateTime.utc(2026, 10, 23, 0, 2);
      final local = CloudRecordEnvelope(
        entityKind: CloudEntityKind.weight,
        recordId: 'row',
        ownerId: 'o',
        revision: CloudRevision(deviceId: 'd', sequence: 1),
        updatedAt: now.subtract(const Duration(minutes: 2)),
        payload: const {'kg': 80},
      );
      final remote = CloudRecordEnvelope(
        entityKind: CloudEntityKind.weight,
        recordId: 'row',
        ownerId: 'o',
        revision: CloudRevision(deviceId: 'other', sequence: 2),
        updatedAt: now.subtract(const Duration(minutes: 1)),
        payload: const {'kg': 81},
      );
      final transport = _ChangedRevisionTransport(remote);
      final runtime = DurableOfflineFirstCloudPlatform(
        store: store,
        transport: transport,
        cipher: _Cipher(),
        connectivity: _Connectivity(true),
        clock: _Clock(now),
        policy: const CloudPlatformPolicy(),
      );
      final consent = CloudPrivacyConsent(
        ownerId: 'o',
        grantedAt: now,
        policy: CloudSelectiveSyncPolicy(
          enabledKinds: const {CloudEntityKind.weight},
        ),
      );
      final device = CloudDeviceRegistration(
        deviceId: 'd',
        ownerId: 'o',
        displayName: 'fixture',
        registeredAt: now,
      );
      final session = CloudSession(
        sessionId: 's',
        ownerId: 'o',
        deviceId: 'd',
        issuedAt: now,
        expiresAt: now.add(const Duration(days: 1)),
      );
      await store.saveInboxRecord(local);
      await runtime.enqueue(record: local, consent: consent);
      final queued = await store.readReadyOperations(
        ownerId: 'o',
        now: now,
        limit: 100,
      );
      final wireChecksum = sha256
          .convert(utf8.encode(jsonEncode(queued.single.record.payload)))
          .toString();
      final report = await runtime.synchronize(
        consent: consent,
        device: device,
        session: session,
      );
      expect(report.conflicts, 1);
      expect(
        (await store.readInboxRecord(remote.stableKey))!.payload,
        remote.payload,
      );
      expect(
        (await store.readConflicts()).single.resolution,
        CloudConflictResolution.remoteWins,
      );
      expect(transport.submitted.single.operationId, queued.single.operationId);
      expect(
        transport.submitted.single.record.payload,
        queued.single.record.payload,
      );
      expect(
        sha256
            .convert(
              utf8.encode(
                jsonEncode(transport.submitted.single.record.payload),
              ),
            )
            .toString(),
        wireChecksum,
      );
      expect(await store.hasIdempotencyKey(queued.single.operationId), isTrue);
      expect(await store.pendingCount(), 0);
      final result = CloudManualSyncResult.fromReports(
        ownerId: 'o',
        produce: const CloudOutboxProductionReport(
          enqueued: 1,
          skippedByPolicy: 0,
          remainingDirty: 0,
        ),
        sync: report,
        apply: const CloudInboxApplyReport(
          applied: 0,
          acknowledged: 1,
          localWins: 0,
          unsupported: 0,
          conflicts: 0,
        ),
      );
      expect(result.completed, isTrue);
      expect(result.conflicts, 0);
      expect(result.reason, isNull);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final preferences = PreferencesRepository(db);
      final status = CloudManualSyncStatusController(
        preferences: preferences,
        runSync: () async => result,
        cloudAvailable: true,
        ownerId: 'o',
      );
      addTearDown(status.dispose);
      await status.runOnce();
      expect(status.state.lastSuccessfulSyncAt, now);
      expect(
        await preferences.get(cloudLastSuccessfulSyncPreferenceKeyFor('o')),
        now.toIso8601String(),
      );
    },
  );
}

final class _ChangedRevisionTransport implements CloudTransport {
  _ChangedRevisionTransport(this.remote);
  final CloudRecordEnvelope remote;
  List<CloudSyncOperation> submitted = [];
  @override
  Future<CloudSyncBatchResult> synchronize({
    required String ownerId,
    required String deviceId,
    required CloudSession session,
    required List<CloudSyncOperation> operations,
    required String? cursor,
  }) async {
    submitted = List.of(operations);
    return CloudSyncBatchResult(
      acknowledgedOperationIds: operations.map((o) => o.operationId),
      remoteRecords: [remote],
      serverCursor: '1',
    );
  }
}

void _classificationMetadataRegressionTests() {
  CloudSyncReport page({
    required int total,
    int? unresolved,
    bool more = false,
  }) => CloudSyncReport(
    startedAt: DateTime.utc(2026),
    completedAt: DateTime.utc(2026),
    pushed: 0,
    pulled: 1,
    conflicts: total,
    classifiedUnresolvedConflicts: unresolved,
    pending: 0,
    availability: more
        ? CloudPlatformAvailability.paused
        : CloudPlatformAvailability.ready,
    diagnostics: const [],
    hasMore: more,
    cursorAdvanced: more,
  );
  test(
    'unclassified legacy conflict and invalid classification remain fail closed',
    () {
      expect(page(total: 1).unresolvedConflicts, 1);
      expect(() => page(total: 1, unresolved: 2), throwsArgumentError);
      expect(() => page(total: 1, unresolved: -1), throwsArgumentError);
    },
  );
  test(
    'earlier unresolved and legacy pages survive a clean final page',
    () async {
      final pages = [
        page(total: 1, unresolved: 0, more: true),
        page(total: 1, more: true),
        page(total: 0, unresolved: 0),
      ];
      var index = 0;
      final report = await drainCloudSyncPages(() async => pages[index++]);
      expect(report.conflicts, 2);
      expect(report.unresolvedConflicts, 1);
      final result = CloudManualSyncResult.fromReports(
        ownerId: 'o',
        produce: const CloudOutboxProductionReport(
          enqueued: 0,
          skippedByPolicy: 0,
          remainingDirty: 0,
        ),
        sync: report,
        apply: const CloudInboxApplyReport(
          applied: 0,
          acknowledged: 0,
          localWins: 0,
          unsupported: 0,
          conflicts: 0,
        ),
      );
      expect(result.completed, isFalse);
      expect(result.completedAt, isNull);
      expect(result.reason, 'progress_conflict_unresolved');
    },
  );
  test(
    'V2 unresolved remains reviewable and inbox unresolved never advances success',
    () {
      for (final v2 in [false, true]) {
        final result = CloudManualSyncResult.fromReports(
          ownerId: 'o',
          produce: const CloudOutboxProductionReport(
            enqueued: 0,
            skippedByPolicy: 0,
            remainingDirty: 0,
          ),
          sync: page(total: 1, unresolved: 0),
          apply: CloudInboxApplyReport(
            applied: 0,
            acknowledged: 0,
            localWins: 0,
            unsupported: 0,
            conflicts: v2 ? 0 : 1,
          ),
          restore: CloudRestoreV2Report(conflicts: v2 ? 1 : 0),
        );
        expect(result.completed, isFalse);
        expect(result.completedAt, isNull);
        expect(
          result.reason,
          v2 ? 'conflict_review_required' : 'progress_conflict_unresolved',
        );
      }
    },
  );
}
