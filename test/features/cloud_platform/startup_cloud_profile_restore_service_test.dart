import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/startup_cloud_profile_restore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const owner = 'owner-a';

  test('owner mismatch never starts a remote progress read', () async {
    final reader = _Reader(records: _restoreBatch(owner));
    final service = _service(
      currentOwner: 'owner-b',
      boundOwner: owner,
      reader: reader,
    );

    expect(await service.restore(owner), isFalse);
    expect(reader.calls, 0);
  });

  test('cross-owner response is rejected before local apply', () async {
    var applied = 0;
    final service = _service(
      currentOwner: owner,
      boundOwner: owner,
      reader: _Reader(records: _restoreBatch('owner-b')),
      apply: (_) async {
        applied++;
        return true;
      },
    );

    expect(await service.restore(owner), isFalse);
    expect(applied, 0);
  });

  test('late network result cannot mutate locally after timeout', () async {
    var applied = 0;
    final pending = Completer<List<CloudRecordEnvelope>>();
    final service = _service(
      currentOwner: owner,
      boundOwner: owner,
      reader: _Reader(pending: pending),
      timeout: const Duration(milliseconds: 5),
      apply: (_) async {
        applied++;
        return true;
      },
    );

    await expectLater(service.restore(owner), throwsA(isA<TimeoutException>()));
    pending.complete(_restoreBatch(owner));
    await Future<void>.delayed(Duration.zero);
    expect(applied, 0);
  });

  test(
    'profile, weight and hydration are applied as one ordered batch',
    () async {
      var applied = 0;
      final remote = <CloudRecordEnvelope>[
        _record(owner, CloudEntityKind.hydration, 'water-1'),
        _record(owner, CloudEntityKind.weight, 'weight-1'),
        _record(owner, CloudEntityKind.profile, 'profile-1'),
      ];
      final service = _service(
        currentOwner: owner,
        boundOwner: owner,
        reader: _Reader(records: remote),
        apply: (records) async {
          applied++;
          expect(records.map((record) => record.entityKind), <CloudEntityKind>[
            CloudEntityKind.profile,
            CloudEntityKind.hydration,
            CloudEntityKind.weight,
          ]);
          expect(() => records.add(records.first), throwsUnsupportedError);
          return true;
        },
      );

      expect(await service.restore(owner), isTrue);
      expect(applied, 1);
    },
  );

  test('missing profile prevents progress-only local mutation', () async {
    var applied = 0;
    final service = _service(
      currentOwner: owner,
      boundOwner: owner,
      reader: _Reader(
        records: <CloudRecordEnvelope>[
          _record(owner, CloudEntityKind.weight, 'weight-1'),
        ],
      ),
      apply: (_) async {
        applied++;
        return true;
      },
    );

    expect(await service.restore(owner), isFalse);
    expect(applied, 0);
  });

  test('unsupported entity prevents the whole local batch', () async {
    var applied = 0;
    final service = _service(
      currentOwner: owner,
      boundOwner: owner,
      reader: _Reader(
        records: <CloudRecordEnvelope>[
          _record(owner, CloudEntityKind.profile, 'profile-1'),
          _record(owner, CloudEntityKind.nutrition, 'meal-1'),
        ],
      ),
      apply: (_) async {
        applied++;
        return true;
      },
    );

    expect(await service.restore(owner), isFalse);
    expect(applied, 0);
  });

  test('account change during read rejects the complete batch', () async {
    var currentOwner = owner;
    var applied = 0;
    final pending = Completer<List<CloudRecordEnvelope>>();
    final service = _service(
      currentOwner: owner,
      currentOwnerReader: () => currentOwner,
      boundOwner: owner,
      reader: _Reader(pending: pending),
      apply: (_) async {
        applied++;
        return true;
      },
    );

    final restore = service.restore(owner);
    await Future<void>.delayed(Duration.zero);
    currentOwner = 'owner-b';
    pending.complete(_restoreBatch(owner));

    expect(await restore, isFalse);
    expect(applied, 0);
  });

  test('network-like restore failures are surfaced for retry', () async {
    final service = _service(
      currentOwner: owner,
      boundOwner: owner,
      reader: _Reader(error: const SocketException('offline')),
    );

    await expectLater(service.restore(owner), throwsA(isA<SocketException>()));
  });

  test('decode-time validation failures are surfaced for retry', () async {
    final service = _service(
      currentOwner: owner,
      boundOwner: owner,
      reader: _Reader(error: const FormatException('bad key')),
    );

    await expectLater(service.restore(owner), throwsA(isA<FormatException>()));
  });
}

StartupCloudProfileRestoreService _service({
  required String? currentOwner,
  StartupOwnerReader? currentOwnerReader,
  required String? boundOwner,
  required StartupCloudProfileReader reader,
  Duration timeout = const Duration(seconds: 1),
  StartupLocalRecordsApplier? apply,
}) => StartupCloudProfileRestoreService(
  currentOwnerId: currentOwnerReader ?? () => currentOwner,
  readBoundOwnerId: () async => boundOwner,
  hasLocalProfile: () async => false,
  reader: reader,
  applyLocalRecords: apply ?? (_) async => true,
  timeout: timeout,
);

List<CloudRecordEnvelope> _restoreBatch(String ownerId) =>
    <CloudRecordEnvelope>[
      _record(ownerId, CloudEntityKind.profile, 'profile-1'),
      _record(ownerId, CloudEntityKind.weight, 'weight-1'),
      _record(ownerId, CloudEntityKind.hydration, 'water-1'),
    ];

CloudRecordEnvelope _record(
  String ownerId,
  CloudEntityKind kind,
  String recordId,
) => CloudRecordEnvelope(
  entityKind: kind,
  recordId: recordId,
  ownerId: ownerId,
  revision: CloudRevision(deviceId: 'device-a', sequence: 1),
  updatedAt: DateTime.utc(2026, 8, 23),
  schemaVersion: 1,
  payload: const <String, Object?>{'fixture': true},
);

final class _Reader implements StartupCloudProfileReader {
  _Reader({
    this.records = const <CloudRecordEnvelope>[],
    this.pending,
    this.error,
  });

  final List<CloudRecordEnvelope> records;
  final Completer<List<CloudRecordEnvelope>>? pending;
  final Object? error;
  int calls = 0;

  @override
  Future<List<CloudRecordEnvelope>> readRestoreRecords(String ownerId) {
    calls++;
    if (error != null) throw error!;
    return pending?.future ?? Future.value(records);
  }
}
