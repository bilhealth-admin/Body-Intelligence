import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/app_database_cloud_inbox_applier.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/app_database_cloud_outbox_producer.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final unsupported in [false, true]) {
    test(
      'actual SQLite restore completed only with supported records $unsupported',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final boundary = LocalDataAccountBoundary(db);
        await boundary.bindAuthenticatedOwner('synthetic-owner');
        final now = DateTime.utc(2026, 10, 12);
        final records = [
          CloudRecordEnvelope(
            ownerId: 'synthetic-owner',
            entityKind: CloudEntityKind.weight,
            recordId: 'synthetic-weight',
            revision: CloudRevision(deviceId: 'remote-device', sequence: 1),
            updatedAt: now,
            payload: {
              'date': now.toIso8601String(),
              'dayKey': '2026-10-12',
              'weight': 80.0,
              'note': null,
              'measurementContext': 'morning',
              'createdAt': now.toIso8601String(),
            },
          ),
          if (unsupported)
            CloudRecordEnvelope(
              ownerId: 'synthetic-owner',
              entityKind: CloudEntityKind.nutrition,
              schemaVersion: 99,
              recordId: 'meal:legacy-test',
              revision: CloudRevision(deviceId: 'remote-device', sequence: 1),
              updatedAt: now,
              payload: const {'recordType': 'meal'},
            ),
        ];
        final apply =
            await AppDatabaseCloudInboxApplier(
              database: db,
              accountBoundary: boundary,
            ).apply(
              ownerId: 'synthetic-owner',
              localDeviceId: 'local-device',
              records: records,
            );
        expect((await db.select(db.weightEntries).get()).single.weight, 80);
        expect(await db.select(db.meals).get(), isEmpty);
        final result = CloudManualSyncResult.fromReports(
          ownerId: 'synthetic-owner',
          produce: const CloudOutboxProductionReport(
            enqueued: 0,
            skippedByPolicy: 0,
            remainingDirty: 0,
          ),
          sync: CloudSyncReport(
            startedAt: now,
            completedAt: now,
            pushed: 0,
            pulled: records.length,
            conflicts: 0,
            pending: 0,
            availability: CloudPlatformAvailability.ready,
            diagnostics: const [],
          ),
          apply: apply,
        );
        expect(result.applied, 1);
        expect(result.unsupported, unsupported ? 1 : 0);
        expect(result.completed, !unsupported);
        expect(result.completedAt, unsupported ? isNull : now);
      },
    );
  }

  test('local conflict cannot overwrite the successful-sync timestamp', () {
    final now = DateTime.utc(2026, 10, 12);
    final result = CloudManualSyncResult.fromReports(
      ownerId: 'synthetic-owner',
      produce: const CloudOutboxProductionReport(
        enqueued: 0,
        skippedByPolicy: 0,
        remainingDirty: 0,
      ),
      sync: CloudSyncReport(
        startedAt: now,
        completedAt: now,
        pushed: 0,
        pulled: 1,
        conflicts: 0,
        pending: 0,
        availability: CloudPlatformAvailability.ready,
        diagnostics: const [],
      ),
      apply: const CloudInboxApplyReport(
        applied: 0,
        acknowledged: 0,
        localWins: 0,
        unsupported: 0,
        conflicts: 1,
      ),
    );
    expect(result.disposition, CloudManualSyncDisposition.partial);
    expect(result.completedAt, isNull);
    expect(result.conflicts, 1);
  });
}
