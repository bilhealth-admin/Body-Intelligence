import 'dart:convert';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/final_vision_nutrition.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_message_nutrition_reader.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'gemini_vision_net_consumers_causal_test.dart'
    show owner, day, seedGemini;

Future<void> closePhotoDay(AppDatabase db, double? net) async {
  await DailyLogRepository(db).startDay(day);
  await seedGemini(db, net);
  await DailyLogRepository(db).closeDay(day);
}

void main() {
  test(
    'explicit reopen and new close retire the previous photo snapshot when no photo rows remain',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        await closePhotoDay(db, 16.9);
        expect(
          (await DailyLogRepository(
            db,
          ).getForDay(day))!.finalVisionNutrientEvidenceJson,
          isNotNull,
        );
        await DailyLogRepository(db).reopenDay(day);
        await db.customStatement('DELETE FROM meal_items');
        await db.customStatement('DELETE FROM meals');
        await DailyLogRepository(db).closeDay(day);
        final reclosed = (await DailyLogRepository(db).getForDay(day))!;
        final retired = FinalVisionNutrition.decode(
          reclosed.finalVisionNutrientEvidenceJson!,
        );
        // The prior Vision day keeps only its lineage for cloud deletion
        // propagation. The new close contains no nutrients from the old photo.
        expect(reclosed.lifecycleState, 'closed');
        expect(retired.logUuid, reclosed.uuid);
        expect(retired.dayKey, reclosed.dayKey);
        expect(retired.closedAtUtc, reclosed.closedAt!.toUtc());
        expect(retired.nutrients.keys.toSet(), FoodNutrient.values.toSet());
        expect(retired.nutrients.values, everyElement(isNull));
        expect(retired.directNetCarbohydrates, isNull);
        expect(
          (await DailyLogRepository(db).readLedger(day)).netCarbohydrates,
          isNull,
        );
      } finally {
        await db.close();
      }
    },
  );
  for (final net in <double?>[null, 16.9, 0]) {
    test(
      'closed snapshot freezes provided net $net and all micronutrients instead of recalculating',
      () async {
        final db = AppDatabase.forTesting(
          NativeDatabase.memory(),
          localOwnerId: owner,
        );
        try {
          await closePhotoDay(db, net);
          final log = (await DailyLogRepository(db).getForDay(day))!;
          final frozen = FinalVisionNutrition.decode(
            log.finalVisionNutrientEvidenceJson!,
          );
          expect(frozen.directNetCarbohydrates, net);
          expect(frozen.nutrients[FoodNutrient.sodium], 0);
          expect(frozen.nutrients[FoodNutrient.potassium], isNull);
          expect(frozen.nutrients[FoodNutrient.vitaminA], 7);
          await db.customStatement(
            'UPDATE meal_items SET carbs = 999, fiber = 0, calories = 999',
          );
          final ledger = await DailyLogRepository(db).readLedger(day);
          expect(ledger.netCarbohydrates, net);
          expect(ledger.calories, 160);
          final visual = await CoachMessageNutritionReader(
            db,
            clock: () => DateTime.utc(2026, 11, 18),
          ).readDay(day, checkAccess: () {});
          expect(
            visual.columns.single.metrics
                .firstWhere((m) => m.id == 'netCarbohydrates')
                .completeValue,
            net,
          );
          expect(
            visual.columns.single.metrics
                .firstWhere((m) => m.id == 'vitaminA')
                .completeValue,
            7,
          );
        } finally {
          await db.close();
        }
      },
    );
  }
  test(
    'closed JSON owner/day/time/projection tampering is unavailable without legacy net fallback',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        await closePhotoDay(db, 16.9);
        final original = (await DailyLogRepository(db).getForDay(day))!;
        final raw =
            jsonDecode(original.finalVisionNutrientEvidenceJson!)
                as Map<String, dynamic>;
        for (final patch in [
          {'ownerKey': 'account_000000000000000000000000'},
          {'dayKey': '2026-11-17'},
          {'logUuid': 'another-record'},
          {'closedAt': '2026-01-01T00:00:00.000Z'},
          {'directNetCarbohydrates': 'not-a-number'},
        ]) {
          await (db.update(
            db.dailyLogs,
          )..where((row) => row.id.equals(original.id))).write(
            DailyLogsCompanion(
              finalVisionNutrientEvidenceJson: Value(
                jsonEncode({...raw, ...patch}),
              ),
            ),
          );
          expect(
            (await DailyLogRepository(db).readLedger(day)).netCarbohydrates,
            isNull,
          );
        }
        await (db.update(
          db.dailyLogs,
        )..where((row) => row.id.equals(original.id))).write(
          const DailyLogsCompanion(
            finalVisionNutrientEvidenceJson: Value(null),
          ),
        );
        expect(
          (await DailyLogRepository(db).readLedger(day)).netCarbohydrates,
          isNull,
        );
      } finally {
        await db.close();
      }
    },
  );
  test(
    'fresh same-owner nutrition cloud restore preserves frozen closed net and excludes private day fields',
    () async {
      final a = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      final b = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        for (final db in [a, b]) {
          await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
        }
        await closePhotoDay(a, 16.9);
        await DailyLogRepository(a).save(
          date: day,
          notes: 'PRIVATE_BODY_NOTE',
          sleepHours: 7,
          steps: 1234,
          exerciseNotes: 'PRIVATE_WORKOUT',
        );
        final snapshots = await CloudNutritionSnapshotCodec(
          a,
          ownerId: owner,
          ownerIsCurrent: () => true,
        ).capture(scopes: {'nutrition'});
        final wire = jsonEncode(snapshots.map((s) => s.toJson()).toList());
        expect(wire, isNot(contains('PRIVATE_BODY_NOTE')));
        expect(wire, isNot(contains('PRIVATE_WORKOUT')));
        final target = CloudNutritionSnapshotCodec(
          b,
          ownerId: owner,
          ownerIsCurrent: () => true,
        );
        for (final snapshot in snapshots) {
          await target.apply(snapshot);
        }
        final restored = (await DailyLogRepository(b).getForDay(day))!;
        expect(restored.lifecycleState, 'closed');
        expect(restored.notes, isNull);
        expect(restored.sleepHours, isNull);
        expect(restored.steps, isNull);
        expect(
          (await DailyLogRepository(b).readLedger(day)).netCarbohydrates,
          16.9,
        );
        expect(
          FinalVisionNutrition.decode(
            restored.finalVisionNutrientEvidenceJson!,
          ).nutrients[FoodNutrient.vitaminA],
          7,
        );
        final meal = snapshots.firstWhere((s) => s.type == 'meal');
        await target.apply(meal);
        expect(await b.select(b.dailyLogs).get(), hasLength(1));
      } finally {
        await a.close();
        await b.close();
      }
    },
  );
  test(
    'restoring a closed projection cannot overwrite a different local open day or notes',
    () async {
      final a = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      final b = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: owner,
      );
      try {
        for (final db in [a, b]) {
          await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
        }
        await closePhotoDay(a, 16.9);
        await DailyLogRepository(b).save(date: day, notes: 'Keep local');
        final snapshot = (await CloudNutritionSnapshotCodec(
          a,
          ownerId: owner,
          ownerIsCurrent: () => true,
        ).capture(scopes: {'nutrition'})).firstWhere((s) => s.type == 'meal');
        await expectLater(
          CloudNutritionSnapshotCodec(
            b,
            ownerId: owner,
            ownerIsCurrent: () => true,
          ).apply(snapshot),
          throwsFormatException,
        );
        expect(
          (await DailyLogRepository(b).getForDay(day))!.notes,
          'Keep local',
        );
        expect(await b.select(b.mealItems).get(), isEmpty);
        expect(await b.select(b.foods).get(), isEmpty);
      } finally {
        await a.close();
        await b.close();
      }
    },
  );
}
