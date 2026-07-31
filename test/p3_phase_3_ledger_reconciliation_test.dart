import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'deleted custom food preserves immutable historical nutrition evidence',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final foods = FoodRepository(database);
      final meals = MealRepository(database);

      final foodId = await foods.addFood(
        name: 'Historical yogurt',
        category: 'custom',
        calories: 120,
        protein: 10,
        carbs: 8,
        fats: 4,
        sodium: 0,
      );
      final mealId = await meals.createMeal(
        date: DateTime.utc(2026, 7, 23, 8),
        name: 'Breakfast',
        type: 'breakfast',
      );
      await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);
      final before = await database.select(database.mealItems).getSingle();

      await foods.deleteCustomFood(foodId);

      expect(
        await foods.findById(
          (await database.select(database.foods).getSingle()).uuid,
        ),
        isNull,
      );
      expect(await foods.search('Historical yogurt'), isEmpty);
      final after = await database.select(database.mealItems).getSingle();
      expect(after.calories, before.calories);
      expect(after.protein, before.protein);
      expect(after.carbs, before.carbs);
      expect(after.fats, before.fats);
      expect(after.nutrientEvidenceMask, before.nutrientEvidenceMask);
      await expectLater(
        meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 50),
        throwsStateError,
      );
    },
  );

  test(
    'ledger and roadmap publish the reconciled Phase 3 closure contract',
    () {
      final ledger = File(
        'docs/phase_3_execution_ledger.md',
      ).readAsStringSync();
      final roadmap = File('docs/ROADMAP.md').readAsStringSync();
      final report = File(
        'docs/PHASE_3_LEDGER_RECONCILIATION.md',
      ).readAsStringSync();

      expect(ledger, isNot(contains('| planned |')));
      expect(ledger, isNot(contains('| in progress |')));
      expect(ledger, contains('| Epic 8 | Product Quality | complete |'));
      expect(ledger, contains('Complete rows | 44'));
      expect(ledger, contains('Phase 3 Product Excellence is complete'));
      expect(roadmap, contains('Phase 3 Product Excellence: **complete**'));
      expect(report, contains('all 44 Phase 3 ledger rows'));
    },
  );
}
