part of 'meal_repository.dart';

class MealWithItems {
  final Meal meal;
  final List<MealItem> items;
  final Map<int, Food> foodsById;

  /// Opaque database owner key used to validate owner-scoped food evidence.
  final String? ownerKey;

  const MealWithItems({
    required this.meal,
    required this.items,
    this.foodsById = const {},
    this.ownerKey,
  });
}

class UsualMealCandidate {
  const UsualMealCandidate({required this.source, required this.occurrences});

  final MealWithItems source;
  final int occurrences;
}
