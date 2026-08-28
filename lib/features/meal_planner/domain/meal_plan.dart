import 'dart:convert';

enum MealPlanDiet { balanced, vegetarian, highProtein }

enum MealPlanBudget { value, standard }

class MealPlanPreferences {
  const MealPlanPreferences({
    this.diet = MealPlanDiet.balanced,
    this.budget = MealPlanBudget.standard,
    this.maxMinutes = 30,
    this.servings = 2,
  });

  final MealPlanDiet diet;
  final MealPlanBudget budget;
  final int maxMinutes;
  final int servings;

  Map<String, Object> toJson() => {
    'diet': diet.name,
    'budget': budget.name,
    'maxMinutes': maxMinutes,
    'servings': servings,
  };

  factory MealPlanPreferences.fromJson(Map<String, dynamic> json) {
    return MealPlanPreferences(
      diet: MealPlanDiet.values.firstWhere(
        (value) => value.name == json['diet'],
        orElse: () => MealPlanDiet.balanced,
      ),
      budget: MealPlanBudget.values.firstWhere(
        (value) => value.name == json['budget'],
        orElse: () => MealPlanBudget.standard,
      ),
      maxMinutes: (json['maxMinutes'] as num?)?.toInt().clamp(10, 60) ?? 30,
      servings: (json['servings'] as num?)?.toInt().clamp(1, 8) ?? 2,
    );
  }
}

class PlannerRecipe {
  const PlannerRecipe({
    required this.id,
    required this.title,
    required this.meal,
    required this.minutes,
    required this.cost,
    required this.vegetarian,
    required this.highProtein,
    required this.ingredients,
    this.dietTags = const <String>{},
    this.allergens = const <String>{},
  });

  final String id;
  final String title;
  final String meal;
  final int minutes;
  final MealPlanBudget cost;
  final bool vegetarian;
  final bool highProtein;
  final Map<String, double> ingredients;
  final Set<String> dietTags;
  final Set<String> allergens;
}

class PlannedMeal {
  const PlannedMeal({required this.day, required this.recipeId});
  final int day;
  final String recipeId;
  Map<String, Object> toJson() => {'day': day, 'recipeId': recipeId};
  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
    day: (json['day'] as num).toInt(),
    recipeId: json['recipeId'] as String,
  );
}

class WeeklyMealPlan {
  const WeeklyMealPlan({required this.createdAt, required this.meals});
  final DateTime createdAt;
  final List<PlannedMeal> meals;

  String encode() => jsonEncode({
    'createdAt': createdAt.toIso8601String(),
    'meals': meals.map((meal) => meal.toJson()).toList(),
  });

  factory WeeklyMealPlan.decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return WeeklyMealPlan(
      createdAt: DateTime.parse(json['createdAt'] as String),
      meals: (json['meals'] as List)
          .cast<Map<String, dynamic>>()
          .map(PlannedMeal.fromJson)
          .toList(growable: false),
    );
  }
}
