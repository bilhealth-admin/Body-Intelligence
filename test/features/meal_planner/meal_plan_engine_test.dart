import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/meal_planner/domain/meal_plan.dart';
import 'package:body_intelligence_log/features/meal_planner/services/meal_plan_engine.dart';

void main() {
  const engine = MealPlanEngine();

  test('creates seven distinct day assignments within preferences', () {
    const preferences = MealPlanPreferences(
      diet: MealPlanDiet.vegetarian,
      budget: MealPlanBudget.value,
      maxMinutes: 20,
      servings: 2,
    );
    final plan = engine.generate(preferences);
    expect(plan.meals, hasLength(7));
    for (final meal in plan.meals) {
      final recipe = recipeById(meal.recipeId)!;
      expect(recipe.vegetarian, isTrue);
      expect(recipe.cost, MealPlanBudget.value);
      expect(recipe.minutes, lessThanOrEqualTo(20));
    }
  });

  test('grocery list aggregates selected servings and survives storage', () {
    const preferences = MealPlanPreferences(servings: 3);
    final plan = engine.generate(preferences);
    final groceries = engine.groceryList(plan, preferences);
    expect(groceries, isNotEmpty);
    final restored = WeeklyMealPlan.decode(plan.encode());
    expect(
      restored.meals.map((item) => item.recipeId),
      plan.meals.map((item) => item.recipeId),
    );
  });

  test('every preview recipe has complete planning values and method', () {
    expect(
      plannerRecipeDetails.keys.toSet(),
      plannerRecipes.map((r) => r.id).toSet(),
    );
    for (final recipe in plannerRecipes) {
      expect(recipe.ingredients, isNotEmpty, reason: recipe.id);
      expect(recipe.minutes, greaterThan(0), reason: recipe.id);
      final details = plannerRecipeDetails[recipe.id]!;
      expect(details.prepMinutes, greaterThan(0), reason: recipe.id);
      expect(details.steps.length, greaterThanOrEqualTo(2), reason: recipe.id);
      expect(details.calories, greaterThan(0), reason: recipe.id);
      expect(details.protein, greaterThan(0), reason: recipe.id);
      expect(details.carbs, greaterThan(0), reason: recipe.id);
      expect(details.fat, greaterThan(0), reason: recipe.id);
      expect(details.fiber, greaterThanOrEqualTo(0), reason: recipe.id);
      expect(details.sugar, greaterThanOrEqualTo(0), reason: recipe.id);
      expect(details.sodium, greaterThanOrEqualTo(0), reason: recipe.id);
      expect(details.potassium, greaterThanOrEqualTo(0), reason: recipe.id);
    }
  });
}
