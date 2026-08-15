import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/recipe_import/domain/trusted_recipe.dart';
import 'package:body_intelligence_log/features/recipe_import/services/trusted_recipe_ingredient_reconciler.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only one normalized exact local food becomes an exact match', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final foods = FoodRepository(database);
    await foods.addFood(
      name: 'Brown rice',
      category: 'grain',
      calories: 100,
      protein: 2,
      carbs: 22,
      fats: 1,
    );
    final authority = FoodRuntimeSearchAuthority(
      foods,
      catalogResolver: () async => null,
    );
    final result = await TrustedRecipeIngredientReconciler(authority).reconcile(
      TrustedRecipeDraft(
        name: 'Bowl',
        servings: 1,
        prepMinutes: 1,
        cookMinutes: 1,
        ingredients: const [
          TrustedRecipeIngredient(
            name: ' brown  rice ',
            quantity: 100,
            unit: 'g',
          ),
        ],
        steps: const ['Cook.'],
        sourceUrl: null,
      ),
    );
    expect(result.single.status, IngredientMatchStatus.exact);
    expect(result.single.foodName, 'Brown rice');
  });

  test('multiple normalized exact foods remain ambiguous', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final foods = FoodRepository(database);
    for (var index = 0; index < 2; index++) {
      await foods.addFood(
        name: 'Chickpeas',
        category: 'legume-$index',
        calories: 164,
        protein: 8.9,
        carbs: 27.4,
        fats: 2.6,
      );
    }
    final authority = FoodRuntimeSearchAuthority(
      foods,
      catalogResolver: () async => null,
    );
    final result = await TrustedRecipeIngredientReconciler(authority).reconcile(
      const TrustedRecipeDraft(
        name: 'Bowl',
        servings: 1,
        prepMinutes: 1,
        cookMinutes: 1,
        ingredients: [
          TrustedRecipeIngredient(name: 'chickpeas', quantity: 100, unit: 'g'),
        ],
        steps: ['Mix.'],
        sourceUrl: null,
      ),
    );
    expect(result.single.status, IngredientMatchStatus.ambiguous);
    expect(result.single.foodId, isNull);
  });

  test('an ingredient with no local authority match remains missing', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final authority = FoodRuntimeSearchAuthority(
      FoodRepository(database),
      catalogResolver: () async => null,
    );
    final result = await TrustedRecipeIngredientReconciler(authority).reconcile(
      const TrustedRecipeDraft(
        name: 'Unknown bowl',
        servings: 1,
        prepMinutes: 1,
        cookMinutes: 1,
        ingredients: [
          TrustedRecipeIngredient(
            name: 'unlisted ingredient',
            quantity: 1,
            unit: 'piece',
          ),
        ],
        steps: ['Review.'],
        sourceUrl: null,
      ),
    );
    expect(result.single.status, IngredientMatchStatus.missing);
    expect(result.single.foodId, isNull);
  });
}
