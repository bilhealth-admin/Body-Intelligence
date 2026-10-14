import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/first_meal_milestone.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_nutrition_snapshot_codec.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/recipe_import/repositories/trusted_recipe_repository.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'support/cloud_nutrition_fixture.dart';

void main() {
  const owner = 'synthetic-nutrition-owner';
  const scopes = {'nutrition', 'goals'};
  late AppDatabase a, b;
  late CloudNutritionSnapshotCodec source, target;
  var current = true;
  setUp(() async {
    current = true;
    a = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: owner);
    b = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: owner);
    for (final db in [a, b]) {
      await LocalDataAccountBoundary(db).bindAuthenticatedOwner(owner);
    }
    source = CloudNutritionSnapshotCodec(
      a,
      ownerId: owner,
      ownerIsCurrent: () => true,
    );
    target = CloudNutritionSnapshotCodec(
      b,
      ownerId: owner,
      ownerIsCurrent: () => current,
    );
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  CloudNutritionSnapshot replace(
    CloudNutritionSnapshot original,
    Map<String, Object?> data,
  ) => CloudNutritionSnapshot(
    scope: original.scope,
    type: original.type,
    id: original.id,
    deleted: original.deleted,
    data: data,
  );
  CloudNutritionSnapshot roundTrip(CloudNutritionSnapshot value) =>
      CloudNutritionSnapshot.fromJson(
        (jsonDecode(jsonEncode(value.toJson())) as Map).cast<String, Object?>(),
      );

  test(
    'food tombstone on empty SQLite survives late historical dependencies',
    () async {
      final fixture = await seedCloudNutritionFixture(a, ownerId: owner);
      final old = await source.capture(scopes: scopes);
      final beforeItems = await a.select(a.mealItems).get();
      final originalFood = (await a.select(a.foods).get()).singleWhere(
        (row) => row.uuid == fixture.foodUuid,
      );
      await FoodRepository(a).deleteCustomFood(originalFood.id);
      final deletion = (await source.capture(
        scopes: {'nutrition'},
      )).singleWhere((row) => row.type == 'food' && row.id == fixture.foodUuid);
      expect(deletion.deleted, isTrue);
      await target.apply(deletion);
      expect(
        await b.select(b.foods).get(),
        isEmpty,
        reason: 'Deletion must not fabricate a nutrition row',
      );
      expect(
        (await target.capture(scopes: {'nutrition'})).single.toJson(),
        deletion.toJson(),
      );
      final restart = CloudNutritionSnapshotCodec(
        b,
        ownerId: owner,
        ownerIsCurrent: () => current,
      );
      for (final record in old.where(
        (row) => row.type == 'meal' || row.type == 'recipe',
      )) {
        await restart.apply(roundTrip(record));
      }
      final afterFood = (await b.select(b.foods).get()).singleWhere(
        (row) => row.uuid == fixture.foodUuid,
      );
      expect(
        afterFood.deletedAt!.toUtc(),
        DateTime.parse(deletion.data['deletedAt']! as String).toUtc(),
      );
      expect(await FoodRepository(b).findById(fixture.foodUuid), isNull);
      final afterItems = await b.select(b.mealItems).get();
      expect(afterItems, hasLength(beforeItems.length));
      for (final before in beforeItems) {
        final after = afterItems.singleWhere((row) => row.uuid == before.uuid);
        expect(after.foodEvidenceJson, before.foodEvidenceJson);
        expect(after.servingSizeSnapshot, before.servingSizeSnapshot);
        expect(after.servingUnitSnapshot, before.servingUnitSnapshot);
        expect(after.quantity, before.quantity);
        for (final nutrient in FoodNutrient.values) {
          expect(
            MealFoodEvidence.read(after).fullValue(nutrient),
            MealFoodEvidence.read(before).fullValue(nutrient),
            reason: nutrient.name,
          );
        }
      }
      expect(
        await TrustedRecipeRepository(PreferencesRepository(b)).load(),
        hasLength(1),
      );
      expect(await b.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        await PreferencesRepository(b).get(firstMealCelebrationPreferenceKey),
        'done',
      );
      expect(
        (await restart.capture(scopes: {'goals'})).every(
          (row) => !(row.data['values']! as Map).keys.any(
            (key) => key.toString().startsWith('cloud.restore.'),
          ),
        ),
        isTrue,
      );
      expect(
        (await restart.capture(scopes: {'nutrition'}))
            .singleWhere(
              (row) => row.type == 'food' && row.id == fixture.foodUuid,
            )
            .deleted,
        isTrue,
      );
    },
  );

  test('invalid late tombstone cannot erase a durable deletion', () async {
    final fixture = await seedCloudNutritionFixture(a, ownerId: owner);
    final originalFood = (await a.select(a.foods).get()).singleWhere(
      (row) => row.uuid == fixture.foodUuid,
    );
    await FoodRepository(a).deleteCustomFood(originalFood.id);
    final deletion = (await source.capture(
      scopes: {'nutrition'},
    )).singleWhere((row) => row.type == 'food' && row.id == fixture.foodUuid);
    await target.apply(deletion);
    for (final corruption in [
      {...deletion.data}..remove('deletedAt'),
      {...deletion.data, 'deletedAt': null},
      {...deletion.data, 'deletedAt': 'not-a-UTC-date'},
      {...deletion.data, 'ownerId': 'foreign-owner'},
      {...deletion.data, 'schema': 'unknown-version'},
    ]) {
      await expectLater(
        target.apply(replace(deletion, corruption)),
        throwsFormatException,
      );
      expect(
        (await target.capture(scopes: {'nutrition'})).single.toJson(),
        deletion.toJson(),
      );
    }
    expect(await b.select(b.foods).get(), isEmpty);
  });

  test(
    'food tombstone requires dated UTC deletion before creating marker',
    () async {
      for (final data in [
        {'schema': CloudNutritionSnapshotCodec.schema, 'ownerId': owner},
        {
          'schema': CloudNutritionSnapshotCodec.schema,
          'ownerId': owner,
          'deletedAt': null,
        },
        {
          'schema': CloudNutritionSnapshotCodec.schema,
          'ownerId': owner,
          'deletedAt': '2026-10-12T23:00:00+03:00',
        },
      ]) {
        final deletion = CloudNutritionSnapshot(
          scope: 'nutrition',
          type: 'food',
          id: 'test-unseen-food',
          deleted: true,
          data: data,
        );
        await expectLater(target.apply(deletion), throwsFormatException);
        expect(await target.capture(scopes: {'nutrition'}), isEmpty);
        expect(await b.select(b.foods).get(), isEmpty);
      }
      // Existing aggregate tombstones intentionally permit an absent date.
      // This food-only hardening must not rewrite that established contract.
      for (final type in ['meal', 'recipe']) {
        await target.apply(
          CloudNutritionSnapshot(
            scope: 'nutrition',
            type: type,
            id: 'test-unseen-$type',
            deleted: true,
            data: {
              'schema': CloudNutritionSnapshotCodec.schema,
              'ownerId': owner,
            },
          ),
        );
      }
      expect(await b.select(b.foods).get(), isEmpty);
      expect(await b.select(b.meals).get(), isEmpty);
    },
  );

  test(
    'account switch during tombstone write rolls back the marker atomically',
    () async {
      final fixture = await seedCloudNutritionFixture(a, ownerId: owner);
      final food = (await a.select(a.foods).get()).singleWhere(
        (row) => row.uuid == fixture.foodUuid,
      );
      await FoodRepository(a).deleteCustomFood(food.id);
      final deletion = (await source.capture(
        scopes: {'nutrition'},
      )).singleWhere((row) => row.type == 'food' && row.id == fixture.foodUuid);
      var lease = true;
      final switcher = _FoodDeletionOwnerSwitch(() => lease = false);
      final other = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(switcher),
        localOwnerId: owner,
      );
      addTearDown(other.close);
      await LocalDataAccountBoundary(other).bindAuthenticatedOwner(owner);
      final codec = CloudNutritionSnapshotCodec(
        other,
        ownerId: owner,
        ownerIsCurrent: () => lease,
      );
      switcher.enabled = true;
      await expectLater(codec.apply(deletion), throwsStateError);
      expect(switcher.triggered, isTrue);
      switcher.enabled = false;
      lease = true;
      expect(await codec.capture(scopes: {'nutrition'}), isEmpty);
      expect(await other.select(other.foods).get(), isEmpty);
      await codec.apply(deletion);
      expect(
        (await codec.capture(scopes: {'nutrition'})).single.deleted,
        isTrue,
      );
    },
  );

  test(
    'late active standalone food cannot revive its deleted identity',
    () async {
      final fixture = await seedCloudNutritionFixture(a, ownerId: owner);
      final before = (await source.capture(
        scopes: {'nutrition'},
      )).singleWhere((row) => row.type == 'food' && row.id == fixture.foodUuid);
      final food = (await a.select(a.foods).get()).singleWhere(
        (row) => row.uuid == fixture.foodUuid,
      );
      await FoodRepository(a).deleteCustomFood(food.id);
      final deletion = (await source.capture(
        scopes: {'nutrition'},
      )).singleWhere((row) => row.type == 'food' && row.id == fixture.foodUuid);
      await target.apply(deletion);
      await expectLater(target.apply(before), throwsFormatException);
      expect(await b.select(b.foods).get(), isEmpty);
      expect(
        (await target.capture(scopes: {'nutrition'})).single.deleted,
        isTrue,
      );
      current = false;
      await expectLater(target.apply(before), throwsStateError);
      current = true;
      expect(
        (await target.capture(scopes: {'nutrition'})).single.toJson(),
        deletion.toJson(),
      );
    },
  );

  for (final tombstones in [false, true]) {
    test(
      'record selector exactly preserves full snapshot content and deletion evidence $tombstones',
      () async {
        final fixture = await seedCloudNutritionFixture(a, ownerId: owner);
        if (tombstones) {
          final food = (await a.select(a.foods).get()).singleWhere(
            (row) => row.uuid == fixture.foodUuid,
          );
          await FoodRepository(a).deleteCustomFood(food.id);
        }
        final full = await source.capture(scopes: scopes);
        expect(full, isNotEmpty);
        for (final record in full) {
          final single = await source.capture(
            scopes: {record.scope},
            recordType: record.type,
            recordId: record.id,
          );
          expect(single, hasLength(1));
          expect(
            single.single.toJson(),
            record.toJson(),
            reason:
                'Selection may reduce reads, never units, nutrition evidence, goals or relationships.',
          );
        }
        expect(
          await source.capture(
            scopes: {'nutrition'},
            recordType: 'meal',
            recordId: 'unknown-synthetic-meal',
          ),
          isEmpty,
        );
        expect(
          () => source.capture(scopes: scopes, recordType: 'meal'),
          throwsFormatException,
        );
      },
    );
  }

  test('empty capture produces no default goal or unrelated record', () async {
    expect(await source.capture(scopes: scopes), isEmpty);
    expect(await source.capture(scopes: const {}), isEmpty);
  });

  test(
    'real SQLite backup fetch does not materialize the unrelated search catalog',
    () async {
      final counter = _FoodFetchCounter();
      final db = AppDatabase.forTesting(
        NativeDatabase.memory().interceptWith(counter),
        localOwnerId: owner,
      );
      addTearDown(db.close);
      await seedCloudNutritionFixture(db, ownerId: owner);
      await db.customStatement(
        '''WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<500)
      INSERT INTO foods(uuid,name,category,calories,protein,carbs,fats,serving_size,serving_unit,is_custom,source)
      SELECT 'catalog-'||x,'Catalog fixture '||x,'test',100,1,10,1,100,'g',0,'TEST unrelated catalog' FROM n''',
      );
      counter.maximumRows = 0;
      final records = await CloudNutritionSnapshotCodec(
        db,
        ownerId: owner,
        ownerIsCurrent: () => true,
      ).capture(scopes: scopes);
      expect(records.where((row) => row.type == 'meal'), hasLength(2));
      expect(counter.maximumRows, lessThanOrEqualTo(3));
    },
  );

  test(
    'reset goals remains an editable empty snapshot, not a tombstone',
    () async {
      await PreferencesRepository(b).set('goal.calories', '1200');
      final empty = source.emptyGoalsSnapshot();
      expect(empty.deleted, isFalse);
      await target.apply(empty);
      expect(await PreferencesRepository(b).get('goal.calories'), isNull);
      expect(await target.capture(scopes: {'goals'}), isEmpty);
      await PreferencesRepository(a).set('goal.calories', '1600');
      await target.apply((await source.capture(scopes: {'goals'})).single);
      expect(await PreferencesRepository(b).get('goal.calories'), '1600');
    },
  );

  test(
    'independent empty SQLite restores UUID relations nineteen nutrients partial serving and exact goals',
    () async {
      final fixture = await seedCloudNutritionFixture(a, ownerId: owner);
      for (final table in ['foods', 'meals', 'meal_items']) {
        await b.customStatement(
          'INSERT INTO sqlite_sequence(name, seq) VALUES (?, ?)',
          [table, 100],
        );
      }
      expect(await b.select(b.foods).get(), isEmpty);
      expect(await b.select(b.meals).get(), isEmpty);
      expect(await b.select(b.mealItems).get(), isEmpty);
      final captured = await source.capture(scopes: scopes);
      // Recipes and meals precede standalone foods: each aggregate is complete.
      for (final record in captured.reversed) {
        await target.apply(roundTrip(record));
      }
      final aFoods = await a.select(a.foods).get();
      final bFoods = await b.select(b.foods).get();
      for (final before in aFoods) {
        final after = bFoods.singleWhere((row) => row.uuid == before.uuid);
        expect(after.id, isNot(before.id));
        expect(after.foodEvidenceJson, before.foodEvidenceJson);
        for (final nutrient in FoodNutrient.values) {
          expect(
            FoodBasisEvidence.read(after).value(nutrient),
            FoodBasisEvidence.read(before).value(nutrient),
            reason: nutrient.name,
          );
        }
      }
      final aItems = await a.select(a.mealItems).get();
      final bItems = await b.select(b.mealItems).get();
      for (final before in aItems) {
        final after = bItems.singleWhere((row) => row.uuid == before.uuid);
        expect(after.id, isNot(before.id));
        expect(after.foodId, isNot(before.foodId));
        expect(after.mealId, isNot(before.mealId));
        expect(after.foodEvidenceJson, before.foodEvidenceJson);
        for (final nutrient in FoodNutrient.values) {
          expect(
            MealFoodEvidence.read(after).fullValue(nutrient),
            MealFoodEvidence.read(before).fullValue(nutrient),
            reason: nutrient.name,
          );
        }
        expect(
          MealFoodEvidence.read(after).fullValue(FoodNutrient.transFat),
          isNull,
        );
        expect(
          MealFoodEvidence.read(after).fullValue(FoodNutrient.cholesterol),
          0,
        );
      }
      final serving = bItems.singleWhere(
        (item) => item.servingUnitSnapshot == 'serving',
      );
      expect(serving.quantity, 0.5);
      expect(serving.servingSizeSnapshot, 1);
      expect(MealFoodEvidence.read(serving).recipe!.servings, 0.5);
      final saved = (await TrustedRecipeRepository(
        PreferencesRepository(b),
      ).load()).single;
      expect(saved.id, fixture.recipeId);
      expect(
        saved.recipe.ingredients.single.sourceRecordId,
        'local:${fixture.foodUuid}',
      );
      expect(
        saved.recipe.sourceUrl.toString(),
        'https://example.test/recipe-source',
      );
      final goals = (await target.capture(scopes: {'goals'})).single;
      final originalGoals = captured.singleWhere((row) => row.scope == 'goals');
      expect(goals.toJson(), originalGoals.toJson());
      final goalValues = Map<String, String>.from(goals.data['values']! as Map);
      final snapshot = NutritionGoalSnapshot.resolve(goalValues, const {});
      expect(snapshot.goals['goal.carbsGrams']!.value, 112.5);
      expect(snapshot.goals['goal.proteinGrams']!.value, 50);
      expect(snapshot.goals['goal.fatGrams']!.value, closeTo(350 / 9, 1e-12));
      expect(snapshot.goals['goal.vitaminAMcg']!.legacyRaw, '10');
      expect(snapshot.goals['goal.vitaminAMcg']!.value, isNull);
      expect(goalValues['goal.lock.protein'], 'true');
      expect(goalValues['goal.macroLastEdited'], 'carbs');
      final schedule = await NutritionGoalScheduleRepository(
        PreferencesRepository(b),
      ).read();
      expect(schedule.dayTargets[DateTime.monday]!.calories, 1000);
      expect(schedule.mealTargets['lunch']!.calories, 400);
      expect(
        await PreferencesRepository(b).get(firstMealCelebrationPreferenceKey),
        'done',
      );
      expect(
        await PreferencesRepository(b).get(firstMealStreakGuidePreferenceKey),
        isNull,
      );
      expect(await b.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      final reader = await MealRepository(
        b,
      ).watchMealsForDate(DateTime(2026, 10, 12)).first;
      expect(reader.length, 2);
      expect(reader.expand((meal) => meal.items).length, 2);
      expect(
        (await target.capture(
          scopes: scopes,
        )).map((row) => row.toJson()).toList(),
        captured.map((row) => row.toJson()).toList(),
      );
      for (final record in captured) {
        await target.apply(roundTrip(record));
      }
      expect(await b.select(b.mealItems).get(), hasLength(2));
      expect(await b.select(b.meals).get(), hasLength(2));
    },
  );

  test(
    'meal dependency never overwrites a newer custom catalog edit',
    () async {
      final fixture = await seedCloudNutritionFixture(a, ownerId: owner);
      final records = await source.capture(scopes: scopes);
      final food = records.singleWhere(
        (row) => row.type == 'food' && row.id == fixture.foodUuid,
      );
      await target.apply(food);
      final local = await (b.select(
        b.foods,
      )..where((row) => row.uuid.equals(fixture.foodUuid))).getSingle();
      await FoodRepository(b).updateCustomFood(
        id: local.id,
        name: 'NEWER LOCAL',
        category: 'custom',
        servingSize: 100,
        servingUnit: 'g',
        calories: 200,
        protein: 10,
        carbs: 20,
        fats: 8,
      );
      await target.apply(
        records.singleWhere(
          (row) => row.type == 'meal' && row.id == fixture.mealUuid,
        ),
      );
      expect(
        (await (b.select(
          b.foods,
        )..where((row) => row.id.equals(local.id))).getSingle()).name,
        'NEWER LOCAL',
      );
      expect((await b.select(b.mealItems).getSingle()).calories, 96);
    },
  );

  test(
    'malformed evidence rolls back foods meal items and milestone together',
    () async {
      await seedCloudNutritionFixture(a, ownerId: owner);
      final record = (await source.capture(
        scopes: scopes,
      )).firstWhere((row) => row.type == 'meal');
      final data = (jsonDecode(jsonEncode(record.data)) as Map)
          .cast<String, Object?>();
      final items = data['items']! as List;
      (items.first as Map)['calories'] = 999;
      await expectLater(
        target.apply(replace(record, data)),
        throwsFormatException,
      );
      expect(await b.select(b.foods).get(), isEmpty);
      expect(await b.select(b.meals).get(), isEmpty);
      expect(await b.select(b.mealItems).get(), isEmpty);
      expect(
        await PreferencesRepository(b).get(firstMealCelebrationPreferenceKey),
        isNull,
      );
    },
  );

  test(
    'missing recipe source food is rejected without partial collection',
    () async {
      await seedCloudNutritionFixture(a, ownerId: owner);
      final recipe = (await source.capture(
        scopes: scopes,
      )).singleWhere((row) => row.type == 'recipe');
      await expectLater(
        target.apply(replace(recipe, {...recipe.data, 'foods': <Object?>[]})),
        throwsFormatException,
      );
      expect(
        await TrustedRecipeRepository(PreferencesRepository(b)).load(),
        isEmpty,
      );
      expect(await b.select(b.foods).get(), isEmpty);
    },
  );

  test(
    'invalid raw goal and unresolved legacy percent survive without fallback or conversion',
    () async {
      await PreferencesRepository(a).setMany({
        'goal.fiber': 'not a number',
        'goal.vitaminC': '10',
        'goal.transFat': '0',
        'goal.origin.goal.fiber': 'unattributed',
        'goal.backup.v1.keep': '{"old":"not a number"}',
      });
      final incoming = (await source.capture(scopes: {'goals'})).single;
      await target.apply(incoming);
      expect(
        (await target.capture(scopes: {'goals'})).single.toJson(),
        incoming.toJson(),
      );
      final values = Map<String, String>.from(incoming.data['values']! as Map);
      final resolved = NutritionGoalSnapshot.resolve(values, const {});
      expect(resolved.goals['goal.fiber']!.status, NutritionGoalStatus.invalid);
      expect(resolved.goals['goal.vitaminCMg']!.legacyRaw, '10');
      expect(resolved.goals['goal.vitaminCMg']!.value, isNull);
      expect(resolved.goals['goal.transFat']!.value, 0);
    },
  );

  test(
    'goal unit is atomic and removes an explicitly absent prior override only',
    () async {
      await PreferencesRepository(a).setMany({
        'goal.calories': '1000',
        'goal.carbsPercent': '45',
        'goal.proteinPercent': '20',
        'goal.fatPercent': '35',
      });
      await PreferencesRepository(b).setMany({
        'goal.calories': '1200',
        'goal.fiber': '25',
        'coach.draft': 'KEEP',
        'commerce.synthetic': 'KEEP',
      });
      await target.apply((await source.capture(scopes: {'goals'})).single);
      expect(await PreferencesRepository(b).get('goal.fiber'), isNull);
      expect(await PreferencesRepository(b).get('goal.calories'), '1000');
      expect(await PreferencesRepository(b).get('coach.draft'), 'KEEP');
      expect(await PreferencesRepository(b).get('commerce.synthetic'), 'KEEP');
    },
  );

  test(
    'unknown goal version and unrelated preference do not erase local values',
    () async {
      await PreferencesRepository(a).set('goal.calories', '1000');
      await PreferencesRepository(b).set('goal.calories', '1200');
      final goals = (await source.capture(scopes: {'goals'})).single;
      await expectLater(
        target.apply(
          replace(goals, {...goals.data, 'referenceVersion': 'future'}),
        ),
        throwsFormatException,
      );
      await expectLater(
        target.apply(
          replace(goals, {
            ...goals.data,
            'values': {'commerce.balance': '999'},
          }),
        ),
        throwsFormatException,
      );
      expect(await PreferencesRepository(b).get('goal.calories'), '1200');
      expect(await PreferencesRepository(b).get('commerce.balance'), isNull);
    },
  );

  test('cross owner payload and retired account visit cannot write', () async {
    await seedCloudNutritionFixture(a, ownerId: owner);
    final record = (await source.capture(scopes: scopes)).first;
    await expectLater(
      target.apply(
        replace(record, {...record.data, 'ownerId': 'another-owner'}),
      ),
      throwsFormatException,
    );
    current = false;
    await expectLater(target.apply(record), throwsStateError);
    expect(await b.select(b.foods).get(), isEmpty);
    expect(await b.select(b.meals).get(), isEmpty);
  });

  test(
    'account visit changes during apply roll back the entire aggregate',
    () async {
      await seedCloudNutritionFixture(a, ownerId: owner);
      final meal = (await source.capture(
        scopes: scopes,
      )).firstWhere((row) => row.type == 'meal');
      var checks = 0;
      final retiring = CloudNutritionSnapshotCodec(
        b,
        ownerId: owner,
        ownerIsCurrent: () => ++checks < 7,
      );
      await expectLater(retiring.apply(meal), throwsStateError);
      expect(await b.select(b.foods).get(), isEmpty);
      expect(await b.select(b.meals).get(), isEmpty);
      expect(await b.select(b.mealItems).get(), isEmpty);
    },
  );

  test('existing ready milestone is not reset by restored history', () async {
    await seedCloudNutritionFixture(a, ownerId: owner);
    await PreferencesRepository(
      b,
    ).set(firstMealCelebrationPreferenceKey, 'ready');
    final meal = (await source.capture(
      scopes: scopes,
    )).firstWhere((row) => row.type == 'meal');
    await target.apply(meal);
    expect(
      await PreferencesRepository(b).get(firstMealCelebrationPreferenceKey),
      'ready',
    );
  });

  test(
    'meal food and recipe tombstones do not delete retained history or duplicate rows',
    () async {
      final fixture = await seedCloudNutritionFixture(a, ownerId: owner);
      final original = await source.capture(scopes: scopes);
      for (final record in original) {
        await target.apply(record);
      }
      final meal = await (a.select(
        a.meals,
      )..where((row) => row.uuid.equals(fixture.mealUuid))).getSingle();
      await MealRepository(a).deleteMealCascade(meal.id);
      final food = await (a.select(
        a.foods,
      )..where((row) => row.uuid.equals(fixture.foodUuid))).getSingle();
      await FoodRepository(a).deleteCustomFood(food.id);
      final latest = await source.capture(scopes: scopes);
      for (final record in latest.where((row) => row.deleted)) {
        await target.apply(record);
        await target.apply(record);
      }
      await target.apply(
        CloudNutritionSnapshot(
          scope: 'nutrition',
          type: 'recipe',
          id: fixture.recipeId,
          deleted: true,
          data: const {
            'schema': CloudNutritionSnapshotCodec.schema,
            'ownerId': owner,
          },
        ),
      );
      expect(
        await TrustedRecipeRepository(PreferencesRepository(b)).load(),
        isEmpty,
      );
      final bMeal = await (b.select(
        b.meals,
      )..where((row) => row.uuid.equals(fixture.mealUuid))).getSingle();
      expect(bMeal.deletedAt, isNotNull);
      expect(await b.select(b.mealItems).get(), hasLength(2));
      expect(
        (await (b.select(
          b.mealItems,
        )..where((row) => row.mealId.equals(bMeal.id))).getSingle()).deletedAt,
        isNotNull,
      );
      expect(await b.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        await PreferencesRepository(b).get(firstMealCelebrationPreferenceKey),
        'done',
      );
    },
  );

  test(
    'wire rejects local IDs and foreign item ownership atomically',
    () async {
      await seedCloudNutritionFixture(a, ownerId: owner);
      final meal = (await source.capture(
        scopes: scopes,
      )).firstWhere((row) => row.type == 'meal');
      final data = (jsonDecode(jsonEncode(meal.data)) as Map)
          .cast<String, Object?>();
      (data['meal']! as Map)['id'] = 3;
      await expectLater(
        target.apply(replace(meal, data)),
        throwsFormatException,
      );
      expect(await b.select(b.meals).get(), isEmpty);
    },
  );
}

final class _FoodFetchCounter extends QueryInterceptor {
  int maximumRows = 0;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (RegExp(r'FROM\s+"?foods"?', caseSensitive: false).hasMatch(statement)) {
      if (rows.length > maximumRows) {
        maximumRows = rows.length;
      }
    }
    return rows;
  }
}

final class _FoodDeletionOwnerSwitch extends QueryInterceptor {
  _FoodDeletionOwnerSwitch(this.onWrite);
  final void Function() onWrite;
  bool enabled = false, triggered = false;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runInsert(statement, args);
    if (enabled &&
        statement.toLowerCase().contains('preferences') &&
        args.any(
          (value) =>
              value is String &&
              value.startsWith('cloud.restore.foodDeletion.v1.'),
        )) {
      triggered = true;
      onWrite();
    }
    return result;
  }
}
