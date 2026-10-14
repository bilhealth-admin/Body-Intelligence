import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/domain/cloud_sync_models.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/app_database_cloud_outbox_producer.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_durable_ports.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_manual_sync_service.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/app_database_cloud_inbox_applier.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';

void main() {
  group('AppDatabase cloud outbox producer', () {
    late AppDatabase database;
    late LocalDataAccountBoundary boundary;
    late _RecordingSink sink;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      boundary = LocalDataAccountBoundary(database);
      sink = _RecordingSink(
        ownerId: 'owner-a',
        deviceId: 'device-a',
        allowedKinds: CloudEntityKind.values.toSet(),
      );
    });

    tearDown(() => database.close());

    test(
      'nutrition envelope retains all nineteen fields and immutable evidence without expanding live consent',
      () async {
        final food = await FoodRepository(database).materializeUnifiedFood(
          UnifiedFood(
            id: 'usda:outbox-test-nineteen',
            name: 'TEST nineteen nutrients',
            serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
            source: FoodDataSource.foundation,
            sourceLabel: 'TEST attributed source',
            verified: true,
            isCustom: false,
            nutrients: {
              for (final n in FoodNutrient.values)
                n: n == FoodNutrient.transFat
                    ? const NutrientAmount.missing()
                    : NutrientAmount.known(
                        n == FoodNutrient.cholesterol ? 0 : 4,
                      ),
            },
          ),
        );
        await MealRepository(database).addReviewedMealItemsAtomically(
          date: DateTime(2026, 10, 11),
          mealType: 'lunch',
          quantitiesInGrams: true,
          items: [(foodId: food.id, quantity: 80.0)],
        );
        final item = await database.select(database.mealItems).getSingle();
        final evidence = MealFoodEvidence.read(item);
        for (final n in FoodNutrient.values) {
          expect(
            evidence.fullValue(n),
            n == FoodNutrient.transFat
                ? isNull
                : closeTo(n == FoodNutrient.cholesterol ? 0 : 3.2, .00001),
          );
        }
        await boundary.bindAuthenticatedOwner('owner-a');
        await AppDatabaseCloudOutboxProducer(
          database: database,
          accountBoundary: boundary,
          sink: sink,
        ).produce();
        final envelope = sink.records.singleWhere(
          (record) => record.payload['recordType'] == 'mealItem',
        );
        expect(envelope.payload['foodEvidenceJson'], item.foodEvidenceJson);
        expect(envelope.payload['foodSourceSnapshot'], item.foodSourceSnapshot);
        expect(envelope.ownerId, 'owner-a');
        expect(envelope.payload['quantity'], 80);
      },
    );

    test(
      '501 actual SQLite weights cannot report completed after the first 500 are queued',
      () async {
        sink._allowedKinds.remove(CloudEntityKind.nutrition);
        final weights = WeightRepository(database);
        for (var i = 0; i < 501; i++) {
          await weights.addWeight(
            80 + i / 1000,
            date: DateTime.utc(2026, 10, 13).add(Duration(days: i)),
          );
        }
        await boundary.bindAuthenticatedOwner('owner-a');
        final producer = AppDatabaseCloudOutboxProducer(
          database: database,
          accountBoundary: boundary,
          sink: sink,
        );
        final first = await producer.produce();
        expect(first.enqueued, 500);
        expect(first.remainingDirty, 1);
        final now = DateTime.utc(2026, 10, 13, 12);
        CloudManualSyncResult summarize(CloudOutboxProductionReport report) =>
            CloudManualSyncResult.fromReports(
              ownerId: 'owner-a',
              produce: report,
              sync: CloudSyncReport(
                startedAt: now,
                completedAt: now,
                pushed: report.enqueued,
                pulled: 0,
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
                conflicts: 0,
              ),
            );
        final partial = summarize(first);
        expect(
          partial.completed,
          isFalse,
          reason:
              'An unqueued eligible row is not a completed synchronization.',
        );
        expect(partial.pending, 1);
        expect(partial.completedAt, isNull);
        final second = await producer.produce();
        expect(second.enqueued, 1);
        expect(second.remainingDirty, 0);
        expect(summarize(second).completed, isTrue);
        expect(
          sink.records.map((record) => record.recordId).toSet(),
          hasLength(501),
        );
        expect(
          await database.select(database.weightEntries).get(),
          hasLength(501),
        );
      },
    );

    test(
      'adopted guest health data becomes durable owner-scoped envelopes',
      () async {
        await PreferencesRepository(database).setMany({
          'profileDateOfBirth': '1990-05-17T00:00:00.000',
          'countryRegion': 'Egypt',
          'onboarding.goalPriorities.v1':
              '{"version":1,"goals":["improveNutrition","loseWeight"]}',
        });
        await UserProfileRepository(database).save(
          gender: 'male',
          age: 36,
          height: 181,
          currentWeight: 90.4,
          targetWeight: 85,
          activityLevel: 'moderate',
          exercises: true,
        );
        await WeightRepository(
          database,
        ).addWeight(90.4, date: DateTime.utc(2026, 8, 17, 7));
        await WaterRepository(
          database,
        ).add(occurredAt: DateTime.utc(2026, 8, 17, 8), amountMl: 2750);
        final foodId = await FoodRepository(database).addFood(
          name: 'Chicken breast',
          category: 'protein',
          calories: 165,
          protein: 31,
          carbs: 0,
          fats: 3.6,
          isCustom: false,
          source: 'seed',
        );
        final mealId = await MealRepository(database).createMeal(
          date: DateTime.utc(2026, 8, 17, 12),
          name: 'Lunch',
          type: 'lunch',
        );
        await MealRepository(
          database,
        ).addMealItem(mealId: mealId, foodId: foodId, quantity: 100);
        await boundary.bindAuthenticatedOwner('owner-a');

        final report = await AppDatabaseCloudOutboxProducer(
          database: database,
          accountBoundary: boundary,
          sink: sink,
        ).produce();

        expect(report.enqueued, 5);
        expect(report.skippedByPolicy, 0);
        expect(report.remainingDirty, 0);
        expect(sink.records, hasLength(5));
        expect(
          sink.records.every((record) => record.ownerId == 'owner-a'),
          isTrue,
        );
        expect(
          sink.records.every(
            (record) => record.revision.deviceId == 'device-a',
          ),
          isTrue,
        );
        expect(
          sink.records.map((record) => record.entityKind).toSet(),
          containsAll(<CloudEntityKind>{
            CloudEntityKind.profile,
            CloudEntityKind.weight,
            CloudEntityKind.hydration,
            CloudEntityKind.nutrition,
          }),
        );

        final weight = await database
            .select(database.weightEntries)
            .getSingle();
        final water = await database.select(database.waterEntries).getSingle();
        final meal = await database.select(database.meals).getSingle();
        final item = await database.select(database.mealItems).getSingle();
        final profile = await database.select(database.userProfile).getSingle();
        expect(profile.syncStatus, 'queued');
        expect(weight.syncStatus, 'queued');
        expect(water.syncStatus, 'queued');
        expect(meal.syncStatus, 'queued');
        expect(item.syncStatus, 'queued');

        final profileEnvelope = sink.records.singleWhere(
          (record) => record.entityKind == CloudEntityKind.profile,
        );
        expect(
          profileEnvelope.payload['profileDateOfBirth'],
          '1990-05-17T00:00:00.000',
        );
        expect(profileEnvelope.payload['countryRegion'], 'Egypt');
        expect(
          profileEnvelope.payload['onboardingGoalPriorities'],
          '{"version":1,"goals":["improveNutrition","loseWeight"]}',
        );

        final weightEnvelope = sink.records.singleWhere(
          (record) => record.entityKind == CloudEntityKind.weight,
        );
        expect(
          weightEnvelope.payload.containsKey('progressPhotoPath'),
          isFalse,
        );
      },
    );

    test('owner mismatch fails before any health row is enqueued', () async {
      await WeightRepository(database).addWeight(80);
      await boundary.bindAuthenticatedOwner('owner-a');
      sink = _RecordingSink(
        ownerId: 'owner-b',
        deviceId: 'device-b',
        allowedKinds: CloudEntityKind.values.toSet(),
      );

      final producer = AppDatabaseCloudOutboxProducer(
        database: database,
        accountBoundary: boundary,
        sink: sink,
      );

      await expectLater(producer.produce(), throwsStateError);
      expect(sink.records, isEmpty);
      expect(
        (await database.select(database.weightEntries).getSingle()).syncStatus,
        'local',
      );
    });

    test(
      'selective policy skips disallowed kinds without consuming batch room',
      () async {
        await UserProfileRepository(database).save(
          gender: 'male',
          age: 36,
          height: 181,
          currentWeight: 80,
          targetWeight: 75,
          activityLevel: 'moderate',
          exercises: true,
        );
        await WeightRepository(
          database,
        ).addWeight(80, date: DateTime.utc(2026, 8, 17, 9));
        await boundary.bindAuthenticatedOwner('owner-a');
        sink = _RecordingSink(
          ownerId: 'owner-a',
          deviceId: 'device-a',
          allowedKinds: const <CloudEntityKind>{CloudEntityKind.weight},
        );

        final report = await AppDatabaseCloudOutboxProducer(
          database: database,
          accountBoundary: boundary,
          sink: sink,
        ).produce(maxRecords: 1);

        expect(report.enqueued, 1);
        expect(report.skippedByPolicy, 1);
        expect(report.remainingDirty, 1);
        expect(report.eligibleRemaining, 0);
        final now = DateTime.utc(2026, 10, 13);
        final completed = CloudManualSyncResult.fromReports(
          ownerId: 'owner-a',
          produce: report,
          sync: CloudSyncReport(
            startedAt: now,
            completedAt: now,
            pushed: 1,
            pulled: 0,
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
            conflicts: 0,
          ),
        );
        expect(
          completed.completed,
          isTrue,
          reason:
              'Rows excluded by the recorded policy must stay local and must not create an upload retry loop.',
        );
        expect(completed.pending, 0);
        expect(sink.records.single.entityKind, CloudEntityKind.weight);
        expect(
          (await database.select(database.weightEntries).getSingle())
              .syncStatus,
          'queued',
        );
        expect(
          (await database.select(database.userProfile).getSingle()).syncStatus,
          'pending',
        );
      },
    );

    test(
      'deleted rows are emitted as tombstones with no health payload',
      () async {
        final id = await WeightRepository(database).addWeight(80);
        await WeightRepository(database).deleteWeight(id);
        await boundary.bindAuthenticatedOwner('owner-a');

        await AppDatabaseCloudOutboxProducer(
          database: database,
          accountBoundary: boundary,
          sink: sink,
        ).produce();

        final record = sink.records.single;
        expect(record.isTombstone, isTrue);
        expect(record.payload, isEmpty);
        expect(
          (await database.select(database.weightEntries).getSingle())
              .syncStatus,
          'queuedDelete',
        );
      },
    );
  });
}

final class _RecordingSink implements CloudRecordOutboxSink {
  _RecordingSink({
    required this.ownerId,
    required this.deviceId,
    required this._allowedKinds,
  });

  @override
  final String ownerId;

  @override
  final String deviceId;

  final Set<CloudEntityKind> _allowedKinds;
  final List<CloudRecordEnvelope> records = <CloudRecordEnvelope>[];

  @override
  bool allows(CloudEntityKind kind) => _allowedKinds.contains(kind);

  @override
  Future<void> enqueue(CloudRecordEnvelope record) async {
    records.add(record);
  }
}
