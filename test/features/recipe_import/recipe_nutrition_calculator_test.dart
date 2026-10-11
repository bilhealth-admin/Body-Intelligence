import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/trusted_recipe.dart';
import 'package:body_intelligence_log/features/recipe_import/services/recipe_nutrition_calculator.dart';
import 'package:body_intelligence_log/features/recipe_import/services/trusted_recipe_ingredient_reconciler.dart';

void main() {
  test('mass and volume are dimension aware; cups cannot invent density', () {
    expect(RecipeNutritionCalculator.portionFactor('kg', .2, 'g', 100), 2);
    expect(RecipeNutritionCalculator.portionFactor('l', .2, 'ml', 100), 2);
    expect(
      RecipeNutritionCalculator.portionFactor('ml', 100, 'g', 100),
      isNull,
    );
    expect(RecipeNutritionCalculator.portionFactor('cup', 1, 'g', 100), isNull);
    expect(RecipeNutritionCalculator.portionFactor('g', 0, 'g', 100), isNull);
  });
  test(
    'known ingredient values are scaled by quantity and recipe servings',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await FoodRepository(db).addFood(
        name: 'Oats',
        category: 'grain',
        calories: 200,
        protein: 10,
        carbs: 30,
        fats: 4,
        servingSize: 100,
        servingUnit: 'g',
        fiber: 5,
      );
      final food = await db.select(db.foods).getSingle();
      const ingredient = TrustedRecipeIngredient(
        name: 'Oats',
        quantity: 200,
        unit: 'g',
      );
      const draft = TrustedRecipeDraft(
        name: 'Oats bowl',
        servings: 2,
        prepMinutes: 1,
        cookMinutes: 1,
        ingredients: [ingredient],
        steps: ['Mix'],
        sourceUrl: null,
      );
      final result = RecipeNutritionCalculator.calculate(draft, [
        TrustedIngredientMatch(
          ingredient: draft.ingredients.single,
          status: IngredientMatchStatus.exact,
          food: food,
        ),
      ]);
      expect(result, isNotNull);
      expect(result!.caloriesKcal, 200);
      expect(result.proteinG, 10);
      expect(result.fiberG, 5);
      expect(result.sodiumMg, isNull);
      expect(result.provenance.recordId, draft.fingerprint);
    },
  );
  test('unlinked ingredients are unavailable, never zero calories', () {
    const ingredient = TrustedRecipeIngredient(
      name: 'Unknown',
      quantity: 100,
      unit: 'g',
    );
    const draft = TrustedRecipeDraft(
      name: 'Unknown bowl',
      servings: 1,
      prepMinutes: 1,
      cookMinutes: 1,
      ingredients: [ingredient],
      steps: ['Mix'],
      sourceUrl: null,
    );
    expect(
      RecipeNutritionCalculator.calculate(draft, [
        const TrustedIngredientMatch(
          ingredient: ingredient,
          status: IngredientMatchStatus.missing,
        ),
      ]),
      isNull,
    );
  });
}
