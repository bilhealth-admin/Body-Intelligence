import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/database/seed_data.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'starter source values survive the complete meal nutrient pipeline',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final foods = FoodRepository(database);
      final meals = MealRepository(database);

      await SeedData.seedStarterCatalog(foods);
      final apple = (await foods.getFoods()).singleWhere(
        (food) => food.name == 'Apple',
      );
      expect(apple.fiber, 2.4);
      expect(apple.sugar, 10.4);
      for (final nutrient in TrackedNutrient.values.where(
        (nutrient) => nutrient != TrackedNutrient.phosphorus,
      )) {
        expect(
          NutrientEvidenceMask.contains(apple.nutrientEvidenceMask, nutrient),
          isTrue,
        );
      }
      expect(
        NutrientEvidenceMask.contains(
          apple.nutrientEvidenceMask,
          TrackedNutrient.phosphorus,
        ),
        isFalse,
      );

      final mealId = await meals.createMeal(
        date: DateTime(2026, 7, 25),
        name: 'Breakfast',
        type: 'breakfast',
      );
      await meals.addMealItem(mealId: mealId, foodId: apple.id, quantity: 50);
      final snapshot = await database.select(database.mealItems).getSingle();

      expect(snapshot.fiber, 1.2);
      expect(snapshot.sugar, 5.2);
      expect(snapshot.sodium, .5);
      expect(snapshot.potassium, 53.5);
      expect(snapshot.calcium, 3);
      expect(snapshot.magnesium, 2.5);
      expect(snapshot.nutrientEvidenceMask, apple.nutrientEvidenceMask);
    },
  );

  test(
    'existing bundled rows with empty masks are repaired at source',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final foods = FoodRepository(database);
      final appleId = await foods.addFood(
        name: 'Apple',
        category: 'Fruit',
        calories: 52,
        protein: .3,
        carbs: 14,
        fats: .2,
        isCustom: false,
      );

      await SeedData.seedStarterCatalog(foods);
      final repaired = await (database.select(
        database.foods,
      )..where((row) => row.id.equals(appleId))).getSingle();
      expect(repaired.potassium, 107);
      expect(repaired.nutrientEvidenceMask, 63);
      expect(repaired.verified, isTrue);
    },
  );
}
