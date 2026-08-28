import 'dart:async';

import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/startup_cloud_profile_restore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const owner = 'owner-a';

  test('owner mismatch never starts a remote profile read', () async {
    final reader = _Reader(profile: _profile(owner));
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
      reader: _Reader(profile: _profile('owner-b')),
      apply: (_) async {
        applied++;
        return true;
      },
    );

    expect(await service.restore(owner), isFalse);
    expect(applied, 0);
  });

  test('timeout fails local-first without applying a profile', () async {
    var applied = 0;
    final service = _service(
      currentOwner: owner,
      boundOwner: owner,
      reader: _Reader(pending: Completer<CloudRecordEnvelope?>()),
      timeout: const Duration(milliseconds: 5),
      apply: (_) async {
        applied++;
        return true;
      },
    );

    expect(await service.restore(owner), isFalse);
    expect(applied, 0);
  });

  test(
    'matching profile is applied once to the matching local owner',
    () async {
      var applied = 0;
      final profile = _profile(owner);
      final service = _service(
        currentOwner: owner,
        boundOwner: owner,
        reader: _Reader(profile: profile),
        apply: (value) async {
          expect(identical(value, profile), isTrue);
          applied++;
          return true;
        },
      );

      expect(await service.restore(owner), isTrue);
      expect(applied, 1);
    },
  );
}

StartupCloudProfileRestoreService _service({
  required String? currentOwner,
  required String? boundOwner,
  required StartupCloudProfileReader reader,
  Duration timeout = const Duration(seconds: 1),
  StartupLocalProfileApplier? apply,
}) => StartupCloudProfileRestoreService(
  currentOwnerId: () => currentOwner,
  readBoundOwnerId: () async => boundOwner,
  hasLocalProfile: () async => false,
  reader: reader,
  applyLocalProfile: apply ?? (_) async => true,
  timeout: timeout,
);

CloudRecordEnvelope _profile(String ownerId) => CloudRecordEnvelope(
  entityKind: CloudEntityKind.profile,
  recordId: 'profile-1',
  ownerId: ownerId,
  revision: CloudRevision(deviceId: 'device-a', sequence: 1),
  updatedAt: DateTime.utc(2026, 8, 23),
  schemaVersion: 1,
  payload: const <String, Object?>{'gender': 'male'},
);

final class _Reader implements StartupCloudProfileReader {
  _Reader({this.profile, this.pending});

  final CloudRecordEnvelope? profile;
  final Completer<CloudRecordEnvelope?>? pending;
  int calls = 0;

  @override
  Future<CloudRecordEnvelope?> readLatestProfile(String ownerId) {
    calls++;
    return pending?.future ?? Future.value(profile);
  }
}
