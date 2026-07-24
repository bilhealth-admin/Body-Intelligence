import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_conflict_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newest tombstone wins and prevents deleted-data resurrection', () {
    final local = _record(
      updatedAt: DateTime.utc(2026, 7, 24),
      deletedAt: DateTime.utc(2026, 7, 24),
    );
    final remote = _record(updatedAt: DateTime.utc(2026, 7, 23));
    final result = const CloudConflictResolver().resolve(
      local: local,
      remote: remote,
    );
    expect(result.resolution, CloudConflictResolution.localWins);
    expect(result.merged?.isTombstone, isTrue);
  });

  test('equal-time conflict resolves deterministically across devices', () {
    final a = _record(device: 'a');
    final b = _record(device: 'b');
    final resolver = const CloudConflictResolver();
    expect(
      resolver.resolve(local: a, remote: b).merged?.revision.deviceId,
      'a',
    );
    expect(
      resolver.resolve(local: b, remote: a).merged?.revision.deviceId,
      'a',
    );
  });
}

CloudRecordEnvelope _record({
  DateTime? updatedAt,
  DateTime? deletedAt,
  String device = 'a',
}) => CloudRecordEnvelope(
  entityKind: CloudEntityKind.weight,
  recordId: 'w1',
  ownerId: 'owner',
  revision: CloudRevision(deviceId: device, sequence: 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 7, 24),
  deletedAt: deletedAt,
  payload: const {'weight': 95.0},
);
