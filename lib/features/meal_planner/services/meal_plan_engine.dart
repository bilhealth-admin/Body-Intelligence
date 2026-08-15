import '../domain/meal_plan.dart';

class MealPlanEngine {
  const MealPlanEngine();

  WeeklyMealPlan generate(MealPlanPreferences preferences) {
    final eligible = plannerRecipes
        .where((recipe) {
          if (recipe.minutes > preferences.maxMinutes) return false;
          if (preferences.budget == MealPlanBudget.value &&
              recipe.cost != MealPlanBudget.value) {
            return false;
          }
          return switch (preferences.diet) {
            MealPlanDiet.vegetarian => recipe.vegetarian,
            MealPlanDiet.highProtein => recipe.highProtein,
            MealPlanDiet.balanced => true,
          };
        })
        .toList(growable: false);
    final source = eligible.isEmpty ? plannerRecipes : eligible;
    return WeeklyMealPlan(
      createdAt: DateTime.now(),
      meals: List.generate(
        7,
        (day) =>
            PlannedMeal(day: day, recipeId: source[day % source.length].id),
      ),
    );
  }

  Map<String, double> groceryList(
    WeeklyMealPlan plan,
    MealPlanPreferences preferences,
  ) {
    final result = <String, double>{};
    for (final meal in plan.meals) {
      final recipe = recipeById(meal.recipeId);
      if (recipe == null) continue;
      for (final ingredient in recipe.ingredients.entries) {
        result.update(
          ingredient.key,
          (value) => value + ingredient.value * preferences.servings,
          ifAbsent: () => ingredient.value * preferences.servings,
        );
      }
    }
    return result;
  }
}

PlannerRecipe? recipeById(String id) {
  for (final recipe in plannerRecipes) {
    if (recipe.id == id) return recipe;
  }
  return null;
}

class PlannerRecipeDetails {
  const PlannerRecipeDetails({
    required this.prepMinutes,
    required this.steps,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.potassium,
  });

  final int prepMinutes;
  final List<String> steps;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final double potassium;
}

const plannerRecipeDetails = <String, PlannerRecipeDetails>{
  'lentil_soup': PlannerRecipeDetails(
    prepMinutes: 8,
    steps: [
      'Rinse the lentils.',
      'Simmer all ingredients until tender.',
      'Blend, taste and season before serving.',
    ],
    calories: 330,
    protein: 20,
    carbs: 55,
    fat: 4,
    fiber: 16,
    sugar: 7,
    sodium: 180,
    potassium: 780,
  ),
  'yogurt_oats': PlannerRecipeDetails(
    prepMinutes: 5,
    steps: [
      'Combine yogurt and oats.',
      'Top with fresh fruit.',
      'Serve now or chill overnight.',
    ],
    calories: 390,
    protein: 23,
    carbs: 57,
    fat: 9,
    fiber: 8,
    sugar: 19,
    sodium: 120,
    potassium: 620,
  ),
  'chicken_rice': PlannerRecipeDetails(
    prepMinutes: 10,
    steps: [
      'Cook the rice.',
      'Cook chicken to a safe internal temperature.',
      'Fold in vegetables and serve.',
    ],
    calories: 520,
    protein: 52,
    carbs: 58,
    fat: 9,
    fiber: 6,
    sugar: 7,
    sodium: 310,
    potassium: 840,
  ),
  'bean_wrap': PlannerRecipeDetails(
    prepMinutes: 8,
    steps: [
      'Warm the beans.',
      'Layer beans and salad on the wrap.',
      'Roll tightly and serve.',
    ],
    calories: 410,
    protein: 18,
    carbs: 67,
    fat: 9,
    fiber: 16,
    sugar: 6,
    sodium: 480,
    potassium: 720,
  ),
  'tuna_potato': PlannerRecipeDetails(
    prepMinutes: 5,
    steps: [
      'Bake or microwave the potato until tender.',
      'Mix tuna with yogurt.',
      'Split, fill and serve.',
    ],
    calories: 430,
    protein: 35,
    carbs: 58,
    fat: 7,
    fiber: 7,
    sugar: 5,
    sodium: 390,
    potassium: 1250,
  ),
  'egg_shakshuka': PlannerRecipeDetails(
    prepMinutes: 7,
    steps: [
      'Soften pepper in a pan.',
      'Simmer the tomatoes.',
      'Add eggs, cover and cook until set.',
    ],
    calories: 310,
    protein: 20,
    carbs: 19,
    fat: 18,
    fiber: 5,
    sugar: 11,
    sodium: 360,
    potassium: 920,
  ),
  'chickpea_bowl': PlannerRecipeDetails(
    prepMinutes: 8,
    steps: [
      'Cook or reheat the grain.',
      'Add chickpeas and vegetables.',
      'Season, toss and serve.',
    ],
    calories: 480,
    protein: 20,
    carbs: 78,
    fat: 10,
    fiber: 17,
    sugar: 10,
    sodium: 260,
    potassium: 910,
  ),
};

const plannerRecipes = <PlannerRecipe>[
  PlannerRecipe(
    id: 'lentil_soup',
    title: 'Red lentil soup',
    meal: 'Dinner',
    minutes: 30,
    cost: MealPlanBudget.value,
    vegetarian: true,
    highProtein: false,
    ingredients: {'Red lentils (cups)': .5, 'Onion': .5, 'Carrot': .5},
  ),
  PlannerRecipe(
    id: 'yogurt_oats',
    title: 'Yogurt oat bowl',
    meal: 'Breakfast',
    minutes: 5,
    cost: MealPlanBudget.value,
    vegetarian: true,
    highProtein: true,
    ingredients: {'Plain yogurt (cups)': 1, 'Oats (cups)': .5, 'Fruit': 1},
  ),
  PlannerRecipe(
    id: 'chicken_rice',
    title: 'Chicken and vegetable rice',
    meal: 'Dinner',
    minutes: 35,
    cost: MealPlanBudget.standard,
    vegetarian: false,
    highProtein: true,
    ingredients: {
      'Chicken breast (g)': 150,
      'Rice (cups)': .5,
      'Mixed vegetables (cups)': 1,
    },
  ),
  PlannerRecipe(
    id: 'bean_wrap',
    title: 'Bean and salad wrap',
    meal: 'Lunch',
    minutes: 15,
    cost: MealPlanBudget.value,
    vegetarian: true,
    highProtein: false,
    ingredients: {
      'Whole-grain wraps': 1,
      'Beans (cups)': .5,
      'Salad (cups)': 1,
    },
  ),
  PlannerRecipe(
    id: 'tuna_potato',
    title: 'Tuna baked potato',
    meal: 'Lunch',
    minutes: 25,
    cost: MealPlanBudget.standard,
    vegetarian: false,
    highProtein: true,
    ingredients: {'Potato': 1, 'Tuna (cans)': .5, 'Plain yogurt (tbsp)': 1},
  ),
  PlannerRecipe(
    id: 'egg_shakshuka',
    title: 'Quick egg shakshuka',
    meal: 'Dinner',
    minutes: 20,
    cost: MealPlanBudget.value,
    vegetarian: true,
    highProtein: true,
    ingredients: {'Eggs': 2, 'Tomatoes (cups)': 1, 'Bell pepper': .5},
  ),
  PlannerRecipe(
    id: 'chickpea_bowl',
    title: 'Chickpea grain bowl',
    meal: 'Lunch',
    minutes: 20,
    cost: MealPlanBudget.value,
    vegetarian: true,
    highProtein: false,
    ingredients: {
      'Chickpeas (cups)': .75,
      'Grain (cups)': .5,
      'Vegetables (cups)': 1,
    },
  ),
];
