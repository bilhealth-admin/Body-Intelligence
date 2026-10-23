import 'dart:io';

import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_identity_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_platform_policy.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/persistence/sqlite_cloud_platform_store.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_platform_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/durable_offline_first_cloud_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

final _now = DateTime.utc(2026, 10, 22);
final _consent = CloudPrivacyConsent(
  ownerId: 'owner',
  grantedAt: _now,
  policy: CloudSelectiveSyncPolicy(enabledKinds: {CloudEntityKind.weight}),
);
final _device = CloudDeviceRegistration(
  deviceId: 'device',
  ownerId: 'owner',
  displayName: 'test',
  registeredAt: _now,
);
final _session = CloudSession(
  sessionId: 'test',
  ownerId: 'owner',
  deviceId: 'device',
  issuedAt: _now,
  expiresAt: _now.add(const Duration(hours: 1)),
);

void main() {
  test(
    'decrypt failure stops once without resurrecting acknowledged outbox',
    () async {
      final store = SqliteCloudPlatformStore.inMemory();
      await store.initialize();
      addTearDown(store.close);
      final transport = _Transport();
      final runtime = _runtime(
        store,
        transport,
        cipher: const _Cipher(fail: true),
      );
      await runtime.enqueue(record: _record('local'), consent: _consent);
      final report = await drainCloudSyncPages(() => _sync(runtime));
      expect(transport.calls, 1);
      expect(report.failureCode, 'cloud_sync_decrypt_failed');
      expect(
        report.diagnostics.join(),
        isNot(contains('private synthetic detail')),
      );
      expect(report.pushed, 1);
      expect(report.completed, isFalse);
      expect(await store.readCursor('owner', 'device'), isNull);
      expect(await store.pendingCount(), 0);
      expect(await store.readDeadLetters(), isEmpty);
    },
  );

  for (final failure in ['cursor', 'inbox']) {
    test(
      'real SQLite $failure failure resumes after reopen without data loss',
      () async {
        final folder = await Directory.systemTemp.createTemp(
          'bil-sync-failure-',
        );
        final path = '${folder.path}/ledger.sqlite';
        var store = SqliteCloudPlatformStore.open(path);
        await store.initialize();
        final raw = sqlite3.open(path);
        addTearDown(() async {
          raw.close();
          await store.close();
          await folder.delete(recursive: true);
        });
        await store.saveInboxRecord(_record('untouched', owner: 'other-owner'));
        if (failure == 'cursor') {
          raw.execute(
            "CREATE TRIGGER synthetic_failure BEFORE INSERT ON cloud_cursors BEGIN SELECT RAISE(ABORT, 'synthetic cursor fault'); END",
          );
        } else {
          raw.execute(
            "CREATE TRIGGER synthetic_failure BEFORE INSERT ON cloud_inbox WHEN NEW.stable_key = 'owner:weight:second' BEGIN SELECT RAISE(ABORT, 'synthetic inbox fault'); END",
          );
        }
        final transport = _Transport();
        var runtime = _runtime(store, transport);
        await runtime.enqueue(record: _record('local'), consent: _consent);
        final failed = await drainCloudSyncPages(() => _sync(runtime));
        expect(transport.calls, 1);
        expect(failed.failureCode, 'cloud_sync_${failure}_write_failed');
        expect(await store.readCursor('owner', 'device'), isNull);
        expect(await store.pendingCount(), 0);
        expect(await store.readDeadLetters(), isEmpty);
        expect(
          await store.readAllRecords('owner'),
          hasLength(failure == 'cursor' ? 2 : 1),
        );
        raw.execute('DROP TRIGGER synthetic_failure');
        await store.close();
        store = SqliteCloudPlatformStore.open(path);
        await store.initialize();
        runtime = _runtime(store, transport);
        final resumed = await drainCloudSyncPages(() => _sync(runtime));
        expect(resumed.completed, isTrue);
        expect(resumed.conflicts, 0);
        expect(await store.readConflicts(), isEmpty);
        expect(await store.readCursor('owner', 'device'), '2');
        expect(await store.readAllRecords('owner'), hasLength(2));
        expect(await store.readAllRecords('other-owner'), hasLength(1));
        expect(transport.submittedLengths, [1, 0]);
      },
    );
  }

  test(
    'exhausted transport retry retains blocked payload without a hot loop',
    () async {
      final store = SqliteCloudPlatformStore.inMemory();
      await store.initialize();
      addTearDown(store.close);
      final transport = _Transport(fail: true);
      final runtime = _runtime(store, transport);
      await runtime.enqueue(record: _record('local'), consent: _consent);
      final first = await drainCloudSyncPages(() => _sync(runtime));
      expect(first.failureCode, 'cloud_sync_transport_failed');
      expect(transport.calls, 1);
      final retried = await store.readReadyOperations(
        ownerId: 'owner',
        now: _now,
        limit: 100,
      );
      expect(retried.single.attempt, 1);
      expect(retried.single.lastError, 'cloud_sync_transport_failed');
      final second = await drainCloudSyncPages(() => _sync(runtime));
      expect(second.completed, isFalse);
      expect(transport.calls, 2);
      expect(await store.pendingCount(ownerId: 'owner'), 1);
      expect(
        await store.readReadyOperations(
          ownerId: 'owner',
          now: _now,
          limit: 100,
        ),
        isEmpty,
      );
      final letters = await store.readDeadLetters();
      expect(letters.single.reason, 'cloud_sync_transport_failed');
      expect(letters.single.attempts, 2);
      // A later read-only page cannot claim full completion while blocked work remains.
      final recovered = await _sync(_runtime(store, _Transport()));
      expect(recovered.failureCode, 'cloud_sync_dead_letters_pending');
      expect(recovered.completed, isFalse);
      expect(await store.pendingCount(ownerId: 'owner'), 1);
    },
  );

  test(
    'unadvanced has-more page is rejected without cursor mutation',
    () async {
      final store = SqliteCloudPlatformStore.inMemory();
      await store.initialize();
      addTearDown(store.close);
      await store.saveCursor('owner', 'device', '2');
      final transport = _Transport(hasMore: true);
      final report = await drainCloudSyncPages(
        () => _sync(_runtime(store, transport)),
      );
      expect(transport.calls, 1);
      expect(report.failureCode, 'cloud_sync_response_validation_failed');
      expect(await store.readCursor('owner', 'device'), '2');
      expect(await store.readAllRecords('owner'), isEmpty);
    },
  );
}

CloudRecordEnvelope _record(
  String id, {
  String owner = 'owner',
  bool reverse = false,
}) => CloudRecordEnvelope(
  entityKind: CloudEntityKind.weight,
  recordId: id,
  ownerId: owner,
  revision: CloudRevision(deviceId: 'device', sequence: 1),
  updatedAt: _now,
  payload: reverse
      ? const {
          'nested': {
            'b': [1, 2],
            'a': true,
          },
          'synthetic': 1,
        }
      : const {
          'synthetic': 1,
          'nested': {
            'a': true,
            'b': [1, 2],
          },
        },
);

DurableOfflineFirstCloudPlatform _runtime(
  SqliteCloudPlatformStore store,
  _Transport transport, {
  CloudPayloadCipher cipher = const _Cipher(),
}) => DurableOfflineFirstCloudPlatform(
  store: store,
  transport: transport,
  cipher: cipher,
  connectivity: _Connectivity(),
  clock: _Clock(),
  policy: const CloudPlatformPolicy(
    retry: CloudRetryPolicy(
      maximumAttempts: 2,
      initialDelay: Duration.zero,
      maximumDelay: Duration.zero,
    ),
  ),
);
Future<CloudSyncReport> _sync(DurableOfflineFirstCloudPlatform runtime) =>
    runtime.synchronize(consent: _consent, device: _device, session: _session);

final class _Clock implements CloudClock {
  @override
  DateTime now() => _now;
}

final class _Connectivity implements CloudConnectivity {
  @override
  bool get isOnline => true;
}

final class _Cipher implements CloudPayloadCipher {
  const _Cipher({this.fail = false});
  final bool fail;
  @override
  bool get isAvailable => true;
  @override
  Future<Map<String, Object?>> encrypt(Map<String, Object?> cleartext) async =>
      cleartext;
  @override
  Future<Map<String, Object?>> decrypt(Map<String, Object?> ciphertext) async {
    if (fail) throw StateError('private synthetic detail');
    return ciphertext;
  }
}

final class _Transport implements CloudTransport {
  _Transport({this.fail = false, this.hasMore = false});
  final bool fail, hasMore;
  int calls = 0;
  final submittedLengths = <int>[];
  @override
  Future<CloudSyncBatchResult> synchronize({
    required String ownerId,
    required String deviceId,
    required CloudSession session,
    required List<CloudSyncOperation> operations,
    required String? cursor,
  }) async {
    calls++;
    submittedLengths.add(operations.length);
    if (fail) throw const SocketException('private synthetic detail');
    return CloudSyncBatchResult(
      acknowledgedOperationIds: operations.map((op) => op.operationId),
      remoteRecords: [
        _record('first', reverse: calls > 1),
        _record('second', reverse: calls > 1),
      ],
      serverCursor: '2',
      hasMore: hasMore,
    );
  }
}
