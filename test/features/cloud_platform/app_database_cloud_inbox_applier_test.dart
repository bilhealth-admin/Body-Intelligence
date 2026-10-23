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

    for (final legacyEmptyBirth in ['', '  ']) {
      test(
        'legacy empty profile birth preference is an idempotent absence [$legacyEmptyBirth]',
        () async {
          final at = DateTime.utc(2026, 10, 23, 12);
          final base = _profileRecord(at);
          final record = CloudRecordEnvelope(
            entityKind: base.entityKind,
            recordId: base.recordId,
            ownerId: base.ownerId,
            revision: base.revision,
            updatedAt: base.updatedAt,
            payload: {...base.payload, 'profileDateOfBirth': legacyEmptyBirth},
          );
          await applier.apply(
            ownerId: 'owner-a',
            localDeviceId: 'device-a',
            records: [record],
          );
          final repeated = await applier.apply(
            ownerId: 'owner-a',
            localDeviceId: 'device-a',
            records: [record],
          );
          expect(repeated.conflicts, 0);
          expect(repeated.acknowledged, 1);
          expect(
            (await database.select(database.preferences).get()).where(
              (r) => r.key == 'profileDateOfBirth',
            ),
            isEmpty,
          );
        },
      );
    }

    test(
      'subsecond metadata replays at actual SQLite storage precision',
      () async {
        final at = DateTime.utc(2026, 10, 23, 12, 30, 15, 123, 456);
        final records = [
          _profileRecord(at),
          _weightRecord(
            deviceId: 'device-b',
            sequence: 1,
            updatedAt: at,
            weight: 80,
            date: at,
            createdAt: at,
          ),
          CloudRecordEnvelope(
            entityKind: CloudEntityKind.hydration,
            recordId: 'water-subseconds',
            ownerId: 'owner-a',
            revision: CloudRevision(deviceId: 'device-b', sequence: 1),
            updatedAt: at,
            payload: {
              'occurredAt': at.toIso8601String(),
              'createdAt': at.toIso8601String(),
              'dayKey': '2026-10-23',
              'amountMl': 250,
            },
          ),
        ];
        await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: records,
        );
        final repeated = await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: records,
        );
        expect(repeated.conflicts, 0);
        expect(repeated.applied, 0);
        expect(repeated.acknowledged, 3);
        expect(
          (await database.select(database.weightEntries).getSingle()).weight,
          80,
        );
      },
    );

    test(
      'a different nonempty birth preference remains a genuine conflict',
      () async {
        final at = DateTime.utc(2026, 10, 23, 12);
        final base = _profileRecord(at, includeOnboardingIdentity: true);
        await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: [base],
        );
        final changed = CloudRecordEnvelope(
          entityKind: base.entityKind,
          recordId: base.recordId,
          ownerId: base.ownerId,
          revision: base.revision,
          updatedAt: base.updatedAt,
          payload: {
            ...base.payload,
            'profileDateOfBirth': '1991-02-03T00:00:00.000',
          },
        );
        final report = await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: [changed],
        );
        expect(report.conflicts, 1);
        final pref = await (database.select(
          database.preferences,
        )..where((r) => r.key.equals('profileDateOfBirth'))).getSingle();
        expect(pref.value, '1990-05-17T00:00:00.000');
      },
    );

    test(
      'replaying restored profile weight and hydration is idempotent',
      () async {
        final at = DateTime.utc(2026, 10, 23, 12);
        final records = [
          _profileRecord(at, includeOnboardingIdentity: true),
          _weightRecord(
            deviceId: 'device-b',
            sequence: 1,
            updatedAt: at,
            weight: 80,
          ),
          CloudRecordEnvelope(
            entityKind: CloudEntityKind.hydration,
            recordId: 'water-replay',
            ownerId: 'owner-a',
            revision: CloudRevision(deviceId: 'device-b', sequence: 1),
            updatedAt: at,
            payload: {
              'occurredAt': at.toIso8601String(),
              'createdAt': at.toIso8601String(),
              'dayKey': '2026-10-23',
              'amountMl': 250,
            },
          ),
        ];
        expect(
          (await applier.apply(
            ownerId: 'owner-a',
            localDeviceId: 'device-a',
            records: records,
          )).applied,
          3,
        );
        final replay = await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: records,
        );
        expect(replay.conflicts, 0);
        expect(replay.acknowledged, 3);
        expect(replay.applied, 0);
        expect(await database.select(database.userProfile).get(), hasLength(1));
        expect(
          await database.select(database.weightEntries).get(),
          hasLength(1),
        );
        expect(
          await database.select(database.waterEntries).get(),
          hasLength(1),
        );
      },
    );

    for (final changedField in ['weight', 'date', 'deleted']) {
      test(
        'equal revision and timestamp do not hide changed $changedField',
        () async {
          final at = DateTime.utc(2026, 10, 23, 12);
          final original = _weightRecord(
            deviceId: 'device-b',
            sequence: 1,
            updatedAt: at,
            weight: 80,
          );
          await applier.apply(
            ownerId: 'owner-a',
            localDeviceId: 'device-a',
            records: [original],
          );
          final different = CloudRecordEnvelope(
            entityKind: original.entityKind,
            recordId: original.recordId,
            ownerId: original.ownerId,
            revision: original.revision,
            updatedAt: original.updatedAt,
            deletedAt: changedField == 'deleted' ? at : null,
            payload: {
              ...original.payload,
              if (changedField == 'weight') 'weight': 79.0,
              if (changedField == 'date') 'date': at.toIso8601String(),
            },
          );
          final report = await applier.apply(
            ownerId: 'owner-a',
            localDeviceId: 'device-a',
            records: [different],
          );
          expect(report.conflicts, 1);
          expect(report.acknowledged, 0);
          final row = await database.select(database.weightEntries).getSingle();
          expect(row.weight, 80);
          expect(row.date, DateTime.utc(2026, 8, 17, 8).toLocal());
          expect(row.deletedAt, isNull);
        },
      );
    }

    test(
      'a matching downloaded row cannot clear a pending local edit',
      () async {
        final at = DateTime.utc(2026, 10, 23, 12);
        final original = _weightRecord(
          deviceId: 'device-b',
          sequence: 1,
          updatedAt: at,
          weight: 80,
        );
        await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: [original],
        );
        await database
            .update(database.weightEntries)
            .write(const WeightEntriesCompanion(syncStatus: Value('pending')));
        final report = await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'device-a',
          records: [original],
        );
        expect(report.conflicts, 1);
        expect(report.acknowledged, 0);
        expect(
          (await database.select(database.weightEntries).getSingle())
              .syncStatus,
          'pending',
        );
      },
    );

    for (final kind in ['profile', 'hydration']) {
      test(
        'same clock $kind changes remain conflicts after restoration',
        () async {
          final at = DateTime.utc(2026, 10, 23, 12);
          final original = kind == 'profile'
              ? _profileRecord(at)
              : CloudRecordEnvelope(
                  entityKind: CloudEntityKind.hydration,
                  recordId: 'water-protected',
                  ownerId: 'owner-a',
                  revision: CloudRevision(deviceId: 'device-b', sequence: 1),
                  updatedAt: at,
                  payload: {
                    'occurredAt': at.toIso8601String(),
                    'createdAt': at.toIso8601String(),
                    'dayKey': '2026-10-23',
                    'amountMl': 250,
                  },
                );
          await applier.apply(
            ownerId: 'owner-a',
            localDeviceId: 'device-a',
            records: [original],
          );
          final changed = CloudRecordEnvelope(
            entityKind: original.entityKind,
            recordId: original.recordId,
            ownerId: original.ownerId,
            revision: original.revision,
            updatedAt: original.updatedAt,
            payload: {
              ...original.payload,
              if (kind == 'profile') 'targetWeight': 55.0,
              if (kind == 'hydration') 'amountMl': 1000,
            },
          );
          final report = await applier.apply(
            ownerId: 'owner-a',
            localDeviceId: 'device-a',
            records: [changed],
          );
          expect(report.conflicts, 1);
          expect(report.acknowledged, 0);
          if (kind == 'profile') {
            expect(
              (await database.select(database.userProfile).getSingle())
                  .targetWeight,
              75,
            );
          } else {
            expect(
              (await database.select(database.waterEntries).getSingle())
                  .amountMl,
              250,
            );
          }
        },
      );
    }

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
      'profile restore also restores onboarding identity preferences',
      () async {
        final updatedAt = DateTime.utc(2026, 8, 23, 10);
        final record = _profileRecord(
          updatedAt,
          includeOnboardingIdentity: true,
        );

        final report = await applier.apply(
          ownerId: 'owner-a',
          localDeviceId: 'startup-read-only-restore',
          records: [record],
        );

        expect(report.applied, 1);
        final preferences = await database.select(database.preferences).get();
        final values = <String, String>{
          for (final row in preferences) row.key: row.value,
        };
        expect(values['profileDateOfBirth'], '1990-05-17T00:00:00.000');
        expect(values['countryRegion'], 'Egypt');
        expect(
          values['onboarding.goalPriorities.v1'],
          '{"version":1,"goals":["improveNutrition","loseWeight"]}',
        );
      },
    );

    test(
      'selective startup batch rolls back when one payload is invalid',
      () async {
        final updatedAt = DateTime.utc(2026, 8, 23, 10);
        final invalidHydration = CloudRecordEnvelope(
          entityKind: CloudEntityKind.hydration,
          recordId: 'water-invalid',
          ownerId: 'owner-a',
          revision: CloudRevision(deviceId: 'device-b', sequence: 1),
          updatedAt: updatedAt,
          payload: <String, Object?>{
            'occurredAt': updatedAt.toIso8601String(),
            'dayKey': '2026-08-23',
            'createdAt': updatedAt.toIso8601String(),
            // `amountMl` deliberately missing after two otherwise valid rows.
          },
        );

        await expectLater(
          applier.apply(
            ownerId: 'owner-a',
            localDeviceId: 'startup-read-only-restore',
            records: <CloudRecordEnvelope>[
              _profileRecord(updatedAt),
              _weightRecord(
                deviceId: 'device-b',
                sequence: 1,
                updatedAt: updatedAt,
                weight: 79.2,
              ),
              invalidHydration,
            ],
          ),
          throwsFormatException,
        );

        expect(await database.select(database.userProfile).get(), isEmpty);
        expect(await database.select(database.weightEntries).get(), isEmpty);
        expect(await database.select(database.waterEntries).get(), isEmpty);
      },
    );

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

CloudRecordEnvelope _profileRecord(
  DateTime updatedAt, {
  bool includeOnboardingIdentity = false,
}) => CloudRecordEnvelope(
  entityKind: CloudEntityKind.profile,
  recordId: 'profile-a',
  ownerId: 'owner-a',
  revision: CloudRevision(deviceId: 'device-b', sequence: 1),
  updatedAt: updatedAt,
  payload: <String, Object?>{
    'gender': 'male',
    'age': 34,
    'height': 178.0,
    'currentWeight': 79.2,
    'targetWeight': 75.0,
    'activityLevel': 'moderate',
    'exercises': true,
    'medicalConditions': null,
    'waist': null,
    'neck': null,
    'chest': null,
    'arm': null,
    'thigh': null,
    if (includeOnboardingIdentity) ...<String, Object?>{
      'profileDateOfBirth': '1990-05-17T00:00:00.000',
      'countryRegion': 'Egypt',
      'onboardingGoalPriorities':
          '{"version":1,"goals":["improveNutrition","loseWeight"]}',
    },
    'createdAt': updatedAt.toIso8601String(),
  },
);

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
