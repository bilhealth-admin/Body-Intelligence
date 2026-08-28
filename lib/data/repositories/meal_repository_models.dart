part of 'meal_repository.dart';

class MealWithItems {
  final Meal meal;
  final List<MealItem> items;
  final Map<int, Food> foodsById;

  const MealWithItems({
    required this.meal,
    required this.items,
    this.foodsById = const {},
  });
}

class UsualMealCandidate {
  const UsualMealCandidate({required this.source, required this.occurrences});

  final MealWithItems source;
  final int occurrences;
}
