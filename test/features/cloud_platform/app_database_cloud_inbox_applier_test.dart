import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/app_database_cloud_inbox_applier.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase cloud inbox applier', () {
    late AppDatabase database;
    late LocalDataAccountBoundary boundary;
    late AppDatabaseCloudInboxApplier applier;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      boundary = LocalDataAccountBoundary(database);
      await boundary.bindAuthenticatedOwner('owner-a');
      applier = AppDatabaseCloudInboxApplier(
        database: database,
        accountBoundary: boundary,
      );
    });

    tearDown(() => database.close());

    test('applies a newer remote weight to an empty local store', () async {
      final record = _weightRecord(
        deviceId: 'device-b',
        sequence: 4,
        updatedAt: DateTime.utc(2026, 8, 17, 10),
        weight: 79.2,
      );

      final report = await applier.apply(
        ownerId: 'owner-a',
        localDeviceId: 'device-a',
        records: [record],
      );

      expect(report.applied, 1);
      final row = await database.select(database.weightEntries).getSingle();
      expect(row.uuid, record.recordId);
      expect(row.weight, 79.2);
      expect(row.syncStatus, 'synced');
      expect(row.revision, 4);
      expect(row.progressPhotoPath, isNull);
    });

    test(
      'own echoed weight marks queued row synced and preserves photo path',
      () async {
        final id = await WeightRepository(database).addWeight(
          80,
          date: DateTime.utc(2026, 8, 17, 8),
          progressPhotoPath: r'C:\private\progress.jpg',
        );
        final local = await (database.select(
          database.weightEntries,
        )..where((row) => row.id.equals(id))).getSingle();
        await (database.update(database.weightEntries)
              ..where((row) => row.id.equals(id)))
            .write(const WeightEntriesCompanion(syncStatus: Value('queued')));

        final record = _weightRecord(
          recordId: local.uuid,
          deviceId: 'device-a',
          sequence: local.revision,
          updatedAt: local.updatedAt,
          weight: 80,
          createdAt: local.createdAt,
          date: local.date,
          dayKey: local.dayKey,
        );

        final report = await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: [record],
        );

        expect(report.acknowledged, 1);
        final row = await (database.select(
          database.weightEntries,
        )..where((candidate) => candidate.id.equals(id))).getSingle();
        expect(row.syncStatus, 'synced');
        expect(row.progressPhotoPath, r'C:\private\progress.jpg');
      },
    );

    test(
      'newer local pending edit is never overwritten by older remote',
      () async {
        final id = await WeightRepository(
          database,
        ).addWeight(80, date: DateTime.utc(2026, 8, 17, 8));
        await WeightRepository(
          database,
        ).updateWeight(id: id, weight: 81, date: DateTime.utc(2026, 8, 17, 8));
        final local = await (database.select(
          database.weightEntries,
        )..where((row) => row.id.equals(id))).getSingle();

        final record = _weightRecord(
          recordId: local.uuid,
          deviceId: 'device-b',
          sequence: 1,
          updatedAt: local.updatedAt.subtract(const Duration(minutes: 1)),
          weight: 70,
          createdAt: local.createdAt,
          date: local.date,
          dayKey: local.dayKey,
        );

        final report = await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: [record],
        );

        expect(report.localWins, 1);
        final row = await (database.select(
          database.weightEntries,
        )..where((candidate) => candidate.id.equals(id))).getSingle();
        expect(row.weight, 81);
        expect(row.syncStatus, 'pending');
      },
    );

    test(
      'remote hydration tombstone soft deletes matching local row',
      () async {
        final id = await WaterRepository(
          database,
        ).add(occurredAt: DateTime.utc(2026, 8, 17, 9), amountMl: 2750);
        final local = await (database.select(
          database.waterEntries,
        )..where((row) => row.id.equals(id))).getSingle();
        final deletedAt = local.updatedAt.add(const Duration(minutes: 2));
        final record = CloudRecordEnvelope(
          entityKind: CloudEntityKind.hydration,
          recordId: local.uuid,
          ownerId: 'owner-a',
          revision: CloudRevision(deviceId: 'device-b', sequence: 2),
          updatedAt: deletedAt,
          deletedAt: deletedAt,
          payload: const <String, Object?>{},
        );

        final report = await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: [record],
        );

        expect(report.applied, 1);
        final row = await (database.select(
          database.waterEntries,
        )..where((candidate) => candidate.id.equals(id))).getSingle();
        expect(row.deletedAt, isNotNull);
        expect(row.syncStatus, 'synced');
      },
    );

    test('cross-account inbox is rejected before local mutation', () async {
      final record = CloudRecordEnvelope(
        entityKind: CloudEntityKind.weight,
        recordId: 'weight-b',
        ownerId: 'owner-b',
        revision: CloudRevision(deviceId: 'device-b', sequence: 1),
        updatedAt: DateTime.utc(2026, 8, 17),
        payload: <String, Object?>{
          'date': DateTime.utc(2026, 8, 17).toIso8601String(),
          'dayKey': '2026-08-17',
          'weight': 70.0,
          'note': null,
          'measurementContext': 'differentConditions',
          'createdAt': DateTime.utc(2026, 8, 17).toIso8601String(),
        },
      );

      await expectLater(
        applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: [record],
        ),
        throwsStateError,
      );
      expect(await database.select(database.weightEntries).get(), isEmpty);
    });

    test(
      'nutrition remains unsupported until relational merge is closed',
      () async {
        final record = CloudRecordEnvelope(
          entityKind: CloudEntityKind.nutrition,
          recordId: 'meal:m1',
          ownerId: 'owner-a',
          revision: CloudRevision(deviceId: 'device-b', sequence: 1),
          updatedAt: DateTime.utc(2026, 8, 17),
          payload: const <String, Object?>{'recordType': 'meal'},
        );

        final report = await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: [record],
        );

        expect(report.unsupported, 1);
        expect(await database.select(database.meals).get(), isEmpty);
      },
    );
  });
}

CloudRecordEnvelope _weightRecord({
  String recordId = 'weight-a',
  required String deviceId,
  required int sequence,
  required DateTime updatedAt,
  required double weight,
  DateTime? createdAt,
  DateTime? date,
  String? dayKey = '2026-08-17',
}) {
  final resolvedDate = date ?? DateTime.utc(2026, 8, 17, 8);
  final resolvedCreatedAt = createdAt ?? DateTime.utc(2026, 8, 17, 8);
  return CloudRecordEnvelope(
    entityKind: CloudEntityKind.weight,
    recordId: recordId,
    ownerId: 'owner-a',
    revision: CloudRevision(deviceId: deviceId, sequence: sequence),
    updatedAt: updatedAt,
    payload: <String, Object?>{
      'date': resolvedDate.toIso8601String(),
      'dayKey': dayKey,
      'weight': weight,
      'note': null,
      'measurementContext': 'differentConditions',
      'createdAt': resolvedCreatedAt.toIso8601String(),
    },
  );
}
