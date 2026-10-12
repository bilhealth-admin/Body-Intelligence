import 'dart:convert';
import 'dart:io';
import 'package:body_intelligence_log/app/services/local_data_lifecycle_service.dart';
import 'package:body_intelligence_log/app/services/local_recovery_service.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrient_daily_references.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PreferencesRepository repo;
  late Directory root;
  const originals = {
    'goal.calories': '1000',
    'goal.carbsPercent': '45',
    'goal.proteinPercent': '20',
    'goal.fatPercent': '35',
    'goal.fiber': '979',
    'goal.sugar': '765',
    'goal.transFat': '89',
    'goal.saturatedFat': '54',
    'goal.cholesterol': '799',
    'goal.vitaminA': '10',
    'goal.vitaminC': '10',
    'goal.calcium': '10',
    'goal.iron': '10',
    'goal.lock.protein': 'true',
    'goal.lockMode.protein': 'grams',
    'goal.origin.goal.fiber': 'saved_override_unattributed',
    'goal.backup.v1.123': '{"version":1,"values":{"goal.fiber":"979"}}',
  };
  setUp(() async {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'goal-test-A',
    );
    repo = PreferencesRepository(db);
    root = await Directory.systemTemp.createTemp('bil-goal-recovery-');
    await repo.setMany(originals);
  });
  tearDown(() async {
    await db.close();
    // Only this synthetic directory created by setUp is removed.
    await root.delete(recursive: true);
  });
  test(
    'portable JSON preserves raw goals units origins locks and old percentages',
    () async {
      final payload =
          jsonDecode(
                await LocalDataLifecycleService(
                  db,
                ).exportJson(displayUnits: 'metric'),
              )
              as Map;
      final prefs = {
        for (final row in payload['preferences'] as List)
          row['key']: row['value'],
      };
      for (final entry in originals.entries) {
        expect(prefs[entry.key], entry.value, reason: entry.key);
      }
      expect(payload['format'], 'BIL local export v3');
      final goal = NutritionGoalSnapshot.resolve(
        originals,
        NutrientDailyReferences.values,
      );
      expect(goal.goals['goal.fiber']!.value, isNull);
      expect(goal.goals['goal.vitaminAMcg']!.value, isNull);
      expect(goal.goals['goal.vitaminAMcg']!.legacyRaw, '10');
    },
  );
  test(
    'actual SQLite recovery restores original values and does not migrate twice',
    () async {
      final recovery = LocalRecoveryService(
        db,
        directoryResolver: () async => root,
      );
      await recovery.resetWithRecovery();
      expect(await repo.get('goal.fiber'), isNull);
      await recovery.restore();
      for (var visit = 0; visit < 2; visit++) {
        final snapshot = await repo
            .watchSnapshot(NutritionGoalSnapshot.storageKeys)
            .first;
        final resolved = NutritionGoalSnapshot.resolve(
          snapshot,
          NutrientDailyReferences.values,
        );
        expect(resolved.goals['goal.fiber']!.raw, '979');
        expect(resolved.goals['goal.fiber']!.value, isNull);
        for (final key in NutritionGoalSnapshot.legacyKeys.keys) {
          expect(resolved.goals[key]!.legacyRaw, '10');
          expect(resolved.goals[key]!.value, isNull);
        }
      }
      for (final entry in originals.entries) {
        expect(await repo.get(entry.key), entry.value, reason: entry.key);
      }
    },
  );
  test(
    'another owner cannot discover or restore a goal recovery snapshot',
    () async {
      await LocalRecoveryService(
        db,
        directoryResolver: () async => root,
      ).createSnapshot();
      final other = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'goal-test-B',
      );
      try {
        final recovery = LocalRecoveryService(
          other,
          directoryResolver: () async => root,
        );
        expect(await recovery.hasValidSnapshot(), isFalse);
        await expectLater(
          recovery.restore(),
          throwsA(isA<RecoverySnapshotException>()),
        );
        expect(await PreferencesRepository(other).get('goal.fiber'), isNull);
      } finally {
        await other.close();
      }
      expect(await repo.get('goal.fiber'), '979');
    },
  );
}
