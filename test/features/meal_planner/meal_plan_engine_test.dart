import 'package:body_intelligence_log/app/localization/bil_locale_policy.dart';
import 'package:body_intelligence_log/features/meal_planner/domain/planner_recipe_display.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/meal_planner/domain/meal_plan.dart';
import 'package:body_intelligence_log/features/meal_planner/services/meal_plan_engine.dart';

void main() {
  const engine = MealPlanEngine();

  test('all seven planner titles and slots cover every production locale', () {
    for (final tag in BilLocalePolicy.productionTags) {
      for (final recipe in plannerRecipes) {
        final title = PlannerRecipeDisplay.title(recipe, tag);
        expect(title.trim(), isNotEmpty, reason: '$tag ${recipe.id}');
        expect(title, tag == 'en' ? recipe.title : isNot(recipe.title));
        final slot = PlannerRecipeDisplay.slot(recipe.meal, tag);
        expect(slot, tag == 'en' ? recipe.meal : isNot(recipe.meal));
      }
    }
    final bean = recipeById('bean_wrap')!;
    expect(PlannerRecipeDisplay.title(bean, 'ar'), 'لفافة بالفاصولياء والسلطة');
    final chicken = recipeById('chicken_rice')!;
    expect(
      PlannerRecipeDisplay.title(chicken, 'pt-BR'),
      'Arroz com frango e legumes',
    );
    expect(
      PlannerRecipeDisplay.title(chicken, 'pt-PT'),
      'Arroz de frango e legumes',
    );
    expect(PlannerRecipeDisplay.title(chicken, 'zh-Hans'), '鸡肉蔬菜饭');
    expect(PlannerRecipeDisplay.title(chicken, 'zh-Hant'), '雞肉蔬菜飯');
  });

  test(
    'planner title fallback preserves explicit caller names and canonical IDs',
    () {
      const custom = PlannerRecipe(
        id: 'bean_wrap',
        title: 'Mum’s special lunch',
        meal: 'Family lunch',
        minutes: 15,
        cost: MealPlanBudget.value,
        vegetarian: true,
        highProtein: false,
        ingredients: {'Family ingredient': 1},
      );
      for (final tag in BilLocalePolicy.productionTags) {
        expect(PlannerRecipeDisplay.title(custom, tag), custom.title);
        expect(PlannerRecipeDisplay.slot(custom.meal, tag), custom.meal);
      }
      final bean = recipeById('bean_wrap')!;
      expect(PlannerRecipeDisplay.title(bean, 'unsupported'), bean.title);
      expect(
        PlannerRecipeDisplay.title(bean, 'PT_br'),
        'Wrap de feijão e salada',
      );
      expect(bean.id, 'bean_wrap');
      expect(bean.title, 'Bean and salad wrap');
    },
  );

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
