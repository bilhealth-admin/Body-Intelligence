import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/nutrition_calculation_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = NutritionCalculationEngine();

  test('scales every known nutrient from the food gram basis', () {
    final food = UnifiedFood(
      id: 'food-1',
      name: 'Test food',
      serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: const {
        FoodNutrient.calories: NutrientAmount.known(200),
        FoodNutrient.protein: NutrientAmount.known(10),
        FoodNutrient.sodium: NutrientAmount.known(80),
      },
      source: FoodDataSource.foundation,
      sourceLabel: 'foundation',
      verified: true,
      isCustom: false,
    );

    final portion = engine.calculate(food: food, grams: 25);

    expect(portion.valueOrZero(FoodNutrient.calories), 50);
    expect(portion.valueOrZero(FoodNutrient.protein), 2.5);
    expect(portion.valueOrZero(FoodNutrient.sodium), 20);
  });

  test('known zero and missing nutrient remain different after scaling', () {
    final food = UnifiedFood(
      id: 'food-2',
      name: 'Evidence food',
      serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: const {
        FoodNutrient.sodium: NutrientAmount.known(0),
        FoodNutrient.fiber: NutrientAmount.missing(),
      },
      source: FoodDataSource.custom,
      sourceLabel: 'custom',
      verified: false,
      isCustom: true,
    );

    final portion = engine.calculate(food: food, grams: 50);

    expect(portion.knownValue(FoodNutrient.sodium), 0);
    expect(portion.knownValue(FoodNutrient.fiber), isNull);
    expect(
      NutrientEvidenceMask.contains(
        portion.nutrientEvidenceMask,
        TrackedNutrient.sodium,
      ),
      isTrue,
    );
    expect(
      NutrientEvidenceMask.contains(
        portion.nutrientEvidenceMask,
        TrackedNutrient.fiber,
      ),
      isFalse,
    );
  });

  test(
    'meal snapshots use the unified calculation and evidence contract',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final foods = FoodRepository(database);
      final meals = MealRepository(database);

      final foodId = await foods.addFood(
        name: 'Snapshot food',
        category: 'custom',
        servingSize: 80,
        servingUnit: 'g',
        calories: 160,
        protein: 8,
        carbs: 20,
        fats: 4,
        fiber: 12,
        sodium: 80,
        potassium: 400,
        magnesium: 60,
        calcium: 120,
        sugar: 10,
      );
      final mealId = await meals.createMeal(
        date: DateTime(2026, 7, 22),
        name: 'Lunch',
        type: 'lunch',
      );

      await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 40);
      final snapshot = await database.select(database.mealItems).getSingle();

      expect(snapshot.calories, 80);
      expect(snapshot.protein, 4);
      expect(snapshot.fiber, 6);
      expect(snapshot.sodium, 40);
      expect(snapshot.potassium, 200);
      expect(snapshot.magnesium, 30);
      expect(snapshot.calcium, 60);
      expect(snapshot.sugar, 5);
      expect(
        NutrientEvidenceMask.contains(
          snapshot.nutrientEvidenceMask,
          TrackedNutrient.sodium,
        ),
        isTrue,
      );
      expect(
        NutrientEvidenceMask.contains(
          snapshot.nutrientEvidenceMask,
          TrackedNutrient.magnesium,
        ),
        isTrue,
      );
    },
  );
}
