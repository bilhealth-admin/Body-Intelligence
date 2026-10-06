import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'schema21 upgrade preserves historical rows and does not invent missing micronutrient evidence',
    () async {
      final directory = await Directory.systemTemp.createTemp('bil-v22-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/legacy.sqlite');
      var database = AppDatabase.forTesting(NativeDatabase(file));
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final food = await foods.addFood(
        name: 'Legacy food',
        category: 'legacy',
        servingSize: 100,
        servingUnit: 'g',
        calories: 100,
        protein: 10,
        carbs: 10,
        fats: 2,
        iron: 4,
        vitaminC: 9,
      );
      final meal = await meals.createMeal(
        date: DateTime(2026, 10, 5),
        name: 'Original meal',
        type: 'lunch',
      );
      await meals.addMealItem(mealId: meal, foodId: food, quantity: 150);
      final before = await database.select(database.mealItems).getSingle();
      final foodBefore = await database.select(database.foods).getSingle();
      await database.customStatement(
        "INSERT INTO preferences (key, value) VALUES ('migration-proof', 'retained')",
      );
      await database.customStatement(
        'ALTER TABLE meal_items DROP COLUMN food_evidence_json',
      );
      await database.customStatement(
        'ALTER TABLE foods DROP COLUMN food_evidence_json',
      );
      await database.customStatement('PRAGMA user_version = 21');
      await database.close();

      database = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(database.close);
      final after = await database.select(database.mealItems).getSingle();
      final foodAfter = await database.select(database.foods).getSingle();
      expect(database.schemaVersion, 22);
      expect(after, before);
      expect(foodAfter, foodBefore);
      expect(after.foodEvidenceJson, isNull);
      expect(foodAfter.foodEvidenceJson, isNull);
      final evidence = MealFoodEvidence.read(after);
      expect(evidence.state, MealFoodEvidenceState.legacy);
      expect(evidence.fullValue(FoodNutrient.calories), 150);
      expect(evidence.fullValue(FoodNutrient.iron), isNull);
      expect(evidence.fullValue(FoodNutrient.vitaminC), isNull);
      expect(
        (await database
                .customSelect(
                  "SELECT value FROM preferences WHERE key='migration-proof'",
                )
                .getSingle())
            .read<String>('value'),
        'retained',
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await database.customSelect('PRAGMA integrity_check').getSingle())
            .read<String>('integrity_check'),
        'ok',
      );
    },
  );
}
