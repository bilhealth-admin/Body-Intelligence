import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/database_migration_fixtures.dart';

void main() {
  group('local database migration preservation gate', () {
    for (final fixture in <DatabaseMigrationFixture>[
      schemaV12Fixture,
      schemaV15Fixture,
    ]) {
      test(
        'schema ${fixture.schemaVersion} upgrades safely to schema 16',
        () async {
          final database = AppDatabase.forTesting(
            NativeDatabase.memory(setup: fixture.install),
          );
          addTearDown(database.close);

          expect(
            await _pragmaInt(database, 'user_version'),
            database.schemaVersion,
          );
          expect(await _pragmaInt(database, 'foreign_keys'), 1);
          expect(await _foreignKeyViolations(database), isEmpty);

          await _expectUserOwnedRowsPreserved(database);
          await _expectSchema16Defaults(database);
          await _expectRequiredIndexes(database);
        },
      );
    }
  });
}

Future<void> _expectUserOwnedRowsPreserved(AppDatabase database) async {
  final profile = await database.select(database.userProfile).getSingle();
  expect(profile.uuid, 'profile-fixture-0001');
  expect(profile.currentWeight, 93.4);
  expect(profile.targetWeight, 85);
  expect(profile.medicalConditions, 'fixture-condition');
  expect(profile.revision, 3);

  final weight = await database.select(database.weightEntries).getSingle();
  expect(weight.uuid, 'weight-fixture-0001');
  expect(weight.weight, 93.4);
  expect(weight.note, 'preserve weight');
  expect(weight.measurementContext, 'morningFasted');

  final log = await database.select(database.dailyLogs).getSingle();
  expect(log.uuid, 'log-fixture-0001');
  expect(log.notes, 'preserve daily log');
  expect(log.water, 2300);
  expect(log.sleepHours, 7.5);
  expect(log.steps, 8500);

  final food = await database.select(database.foods).getSingle();
  expect(food.uuid, 'food-fixture-0001');
  expect(food.name, 'Fixture oats');
  expect(food.arabicName, 'شوفان الاختبار');
  expect(food.calories, 389);
  expect(food.fiber, 8.4);
  expect(food.magnesium, 177);

  final meal = await database.select(database.meals).getSingle();
  expect(meal.uuid, 'meal-fixture-0001');
  expect(meal.name, 'Breakfast');

  final item = await database.select(database.mealItems).getSingle();
  expect(item.uuid, 'item-fixture-0001');
  expect(item.mealId, meal.id);
  expect(item.foodId, food.id);
  expect(item.quantity, 50);
  expect(item.calories, 194.5);
  expect(item.fiber, 4.2);

  expect(await database.select(database.favorites).get(), hasLength(1));
  expect(await database.select(database.recentFoods).get(), hasLength(1));
  expect(await database.select(database.goals).get(), hasLength(1));

  final water = await database.select(database.waterEntries).getSingle();
  expect(water.uuid, 'water-fixture-0001');
  expect(water.amountMl, 500);

  final preference = await database.select(database.preferences).getSingle();
  expect(preference.key, 'locale');
  expect(preference.value, 'ar');

  final context = await database
      .select(database.lifeContextEntries)
      .getSingle();
  expect(context.uuid, 'context-fixture-0001');
  expect(context.details, 'preserve context');

  final decision = await database.select(database.decisionMemories).getSingle();
  expect(decision.uuid, 'decision-fixture-0001');
  expect(decision.recommendationKey, 'hydrate');
  expect(decision.response, 'accepted');
  expect(decision.outcome, 'helped');

  final plan = await database.select(database.planSettings).getSingle();
  expect(plan.uuid, 'plan-fixture-0001');
  expect(plan.recommendedCalories, 2100);
  expect(plan.assumptionsVersion, 'fixture-v1');

  final experiment = await database
      .select(database.personalExperiments)
      .getSingle();
  expect(experiment.uuid, 'experiment-fixture-0001');
  expect(experiment.result, 'preserve result');

  final challenge = await database.select(database.challenges).getSingle();
  expect(challenge.uuid, 'challenge-fixture-0001');
  expect(challenge.title, 'Hydration fixture');
}

Future<void> _expectSchema16Defaults(AppDatabase database) async {
  final log = await database.select(database.dailyLogs).getSingle();
  final food = await database.select(database.foods).getSingle();
  final item = await database.select(database.mealItems).getSingle();

  expect(log.lifecycleState, 'open');
  expect(log.closedAt, isNull);
  expect(log.finalFiber, isNull);
  expect(log.finalNutrientEvidenceMask, 0);

  expect(food.phosphorus, 0);
  expect(item.phosphorus, 0);
  expect(item.revision, 1);
  expect(item.syncStatus, 'local');
  expect(item.position, item.id);

  expect(
    NutrientEvidenceMask.contains(
      food.nutrientEvidenceMask,
      TrackedNutrient.fiber,
    ),
    isTrue,
  );
  expect(
    NutrientEvidenceMask.contains(
      food.nutrientEvidenceMask,
      TrackedNutrient.magnesium,
    ),
    isTrue,
  );
  expect(
    NutrientEvidenceMask.contains(
      item.nutrientEvidenceMask,
      TrackedNutrient.potassium,
    ),
    isTrue,
  );
}

Future<void> _expectRequiredIndexes(AppDatabase database) async {
  final rows = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  final names = rows.map((row) => row.read<String>('name')).toSet();

  expect(
    names,
    containsAll(<String>[
      'weight_entries_active_day_uq',
      'meals_active_day_type_idx',
      'meal_items_active_meal_idx',
      'water_entries_active_day_idx',
      'life_context_active_day_idx',
      'recent_foods_last_used_idx',
      'challenges_active_started_idx',
      'experiments_active_started_idx',
    ]),
  );
}

Future<int> _pragmaInt(AppDatabase database, String pragma) async {
  final row = await database.customSelect('PRAGMA $pragma').getSingle();
  return row.read<int>(pragma);
}

Future<List<Object?>> _foreignKeyViolations(AppDatabase database) async {
  final rows = await database.customSelect('PRAGMA foreign_key_check').get();
  return rows.map((row) => row.data).toList(growable: false);
}
