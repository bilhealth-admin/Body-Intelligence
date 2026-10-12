import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/local_data_account_boundary.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/trusted_recipe.dart';
import 'package:body_intelligence_log/features/recipe_import/repositories/trusted_recipe_repository.dart';
import 'package:body_intelligence_log/features/recipe_import/services/trusted_recipe_diary_service.dart';

final class CloudNutritionFixtureData {
  const CloudNutritionFixtureData({
    required this.foodUuid,
    required this.recipeId,
    required this.mealUuid,
    required this.recipeMealUuid,
  });
  final String foodUuid, recipeId, mealUuid, recipeMealUuid;
}

/// Synthetic authoring through production repositories, never codec JSON.
Future<CloudNutritionFixtureData> seedCloudNutritionFixture(
  AppDatabase db, {
  required String ownerId,
}) async {
  if (db.localOwnerId != ownerId) throw ArgumentError('Fixture owner mismatch');
  await LocalDataAccountBoundary(db).bindAuthenticatedOwner(ownerId);
  final foods = FoodRepository(db);
  final meals = MealRepository(db);
  final id = await foods.addFood(
    uuid: 'test-custom-full-nutrition',
    name: 'TEST lentils',
    arabicName: 'عدس تجريبي',
    category: 'custom',
    servingSize: 100,
    servingUnit: 'g',
    source: 'TEST explicitly entered source',
    calories: 120,
    protein: 5,
    carbs: 20,
    fats: 3,
    fiber: 4,
    sugar: 0,
    sodium: null,
    potassium: 200,
    calcium: 30,
    magnesium: 15,
    phosphorus: 90,
    iron: 2,
    vitaminC: 9,
    additionalNutrients: const {
      FoodNutrient.saturatedFat: 0.5,
      FoodNutrient.polyunsaturatedFat: 1,
      FoodNutrient.monounsaturatedFat: 0,
      FoodNutrient.transFat: null,
      FoodNutrient.cholesterol: 0,
      FoodNutrient.vitaminA: 100,
    },
  );
  final food = await (db.select(
    db.foods,
  )..where((row) => row.id.equals(id))).getSingle();
  final saved = await TrustedRecipeRepository(PreferencesRepository(db))
      .saveReviewed(
        TrustedRecipeDraft(
          name: 'TEST reviewed lentil recipe',
          servings: 2,
          prepMinutes: 5,
          cookMinutes: 10,
          ingredients: [
            TrustedRecipeIngredient(
              name: food.name,
              quantity: 100,
              unit: 'g',
              sourceRecordId: 'local:${food.uuid}',
            ),
          ],
          steps: const ['TEST cook and divide into two servings.'],
          sourceUrl: Uri.parse('https://example.test/recipe-source'),
          nutrition: TrustedRecipeNutrition(
            caloriesKcal: 300,
            proteinG: 10,
            carbohydrateG: 40,
            fatG: 8,
            fiberG: 3,
            sugarG: 0,
            sodiumMg: null,
            potassiumMg: 200,
            calciumMg: 30,
            magnesiumMg: 15,
            phosphorusMg: 90,
            ironMg: 2,
            vitaminCMg: 15,
            additionalNutrients: const {
              FoodNutrient.saturatedFat: 1,
              FoodNutrient.polyunsaturatedFat: 1.5,
              FoodNutrient.monounsaturatedFat: 0,
              FoodNutrient.transFat: null,
              FoodNutrient.cholesterol: 0,
              FoodNutrient.vitaminA: 120,
            },
            provenance: RecipeNutritionProvenance(
              source: 'TEST calculation',
              recordId: food.uuid,
              verifiedAt: DateTime.utc(2026, 10, 12),
            ),
          ),
        ),
      );
  await meals.addReviewedMealItemsAtomically(
    date: DateTime(2026, 10, 12),
    mealType: 'breakfast',
    quantitiesInGrams: true,
    items: [(foodId: food.id, quantity: 80.0)],
  );
  await TrustedRecipeDiaryService(foods, meals).addServing(
    saved: saved,
    date: DateTime(2026, 10, 12),
    mealType: 'lunch',
    servings: 0.5,
  );
  final preferences = PreferencesRepository(db);
  await preferences.setMany({
    'goal.calories': '1000',
    'goal.carbsPercent': '45',
    'goal.proteinPercent': '20',
    'goal.fatPercent': '35',
    'goal.carbsGrams': '112.5',
    'goal.proteinGrams': '50',
    'goal.fatGrams': (350 / 9).toString(),
    'goal.lock.protein': 'true',
    'goal.lockMode.protein': 'grams',
    'goal.macroLastEdited': 'carbs',
    'goal.macroEditor.v2': 'true',
    'goal.origin.goal.calories': 'manual_override',
    'goal.origin.goal.proteinGrams': 'manual_override',
    'goal.fiber': '30',
    'goal.transFat': '0',
    'goal.vitaminA': '10',
    'goal.backup.v1.test': jsonEncode({
      'version': 1,
      'values': {'goal.vitaminA': '10'},
    }),
  });
  await NutritionGoalScheduleRepository(preferences).saveDay(
    DateTime.monday,
    NutritionGoalTarget.fromGrams(
      calories: 1000,
      carbsGrams: 112.5,
      proteinGrams: 50,
      fatGrams: 350 / 9,
    ),
  );
  await NutritionGoalScheduleRepository(preferences).saveMeal(
    'lunch',
    NutritionGoalTarget.fromGrams(
      calories: 400,
      carbsGrams: 45,
      proteinGrams: 20,
      fatGrams: 140 / 9,
    ),
  );
  final rows = await db.select(db.meals).get();
  return CloudNutritionFixtureData(
    foodUuid: food.uuid,
    recipeId: saved.id,
    mealUuid: rows.singleWhere((meal) => meal.type == 'breakfast').uuid,
    recipeMealUuid: rows.singleWhere((meal) => meal.type == 'lunch').uuid,
  );
}
