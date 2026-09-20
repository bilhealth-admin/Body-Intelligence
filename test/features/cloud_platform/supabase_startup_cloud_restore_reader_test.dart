import 'dart:io';

import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/supabase_startup_cloud_profile_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const owner = 'owner-a';

  test(
    'reader decodes only latest profile plus weight and hydration',
    () async {
      final records = await decodeStartupCloudRestoreRows(
        ownerId: owner,
        decryptPayload: (payload) async => payload,
        rows: <Map<String, Object?>>[
          _row(
            owner: owner,
            kind: CloudEntityKind.profile,
            id: 'profile-old',
            updatedAt: DateTime.utc(2026, 8, 20),
          ),
          _row(
            owner: owner,
            kind: CloudEntityKind.hydration,
            id: 'water-1',
            updatedAt: DateTime.utc(2026, 8, 22),
          ),
          _row(
            owner: owner,
            kind: CloudEntityKind.profile,
            id: 'profile-new',
            updatedAt: DateTime.utc(2026, 8, 23),
          ),
          _row(
            owner: owner,
            kind: CloudEntityKind.weight,
            id: 'weight-1',
            updatedAt: DateTime.utc(2026, 8, 21),
          ),
        ],
      );

      expect(
        records.map((record) => '${record.entityKind.name}:${record.recordId}'),
        <String>['profile:profile-new', 'weight:weight-1', 'hydration:water-1'],
      );
    },
  );

  test('reader rejects cross-owner and unsupported rows', () async {
    await expectLater(
      decodeStartupCloudRestoreRows(
        ownerId: owner,
        decryptPayload: (payload) async => payload,
        rows: <Map<String, Object?>>[
          _row(
            owner: 'owner-b',
            kind: CloudEntityKind.profile,
            id: 'profile-1',
            updatedAt: DateTime.utc(2026, 8, 23),
          ),
        ],
      ),
      throwsFormatException,
    );

    await expectLater(
      decodeStartupCloudRestoreRows(
        ownerId: owner,
        decryptPayload: (payload) async => payload,
        rows: <Map<String, Object?>>[
          _row(
            owner: owner,
            kind: CloudEntityKind.nutrition,
            id: 'meal-1',
            updatedAt: DateTime.utc(2026, 8, 23),
          ),
        ],
      ),
      throwsFormatException,
    );
  });

  test(
    'production reader remains paged, owner-scoped and remote read-only',
    () {
      final source = File(
        'lib/features/cloud_platform/services/'
        'supabase_startup_cloud_profile_reader.dart',
      ).readAsStringSync();

      expect(source, contains(".from('bil_cloud_records')"));
      expect(source, contains(".eq('owner_id', owner)"));
      expect(source, contains(".inFilter(\n            'entity_kind'"));
      expect(source, contains(".isFilter('deleted_at', null)"));
      expect(source, contains('.range(offset, offset + pageSize - 1)'));
      expect(source, contains('keyRepository.resolveExisting(owner)'));
      for (final mutation in [
        '.insert(',
        '.update(',
        '.upsert(',
        "'bil_sync_records'",
        'resolve(owner)',
      ]) {
        expect(source, isNot(contains(mutation)), reason: mutation);
      }
    },
  );
}

Map<String, Object?> _row({
  required String owner,
  required CloudEntityKind kind,
  required String id,
  required DateTime updatedAt,
}) => <String, Object?>{
  'owner_id': owner,
  'entity_kind': kind.name,
  'record_id': id,
  'revision_device_id': 'device-a',
  'revision_sequence': 1,
  'updated_at': updatedAt.toIso8601String(),
  'deleted_at': null,
  'schema_version': 1,
  'payload': <String, Object?>{'kind': kind.name},
};
