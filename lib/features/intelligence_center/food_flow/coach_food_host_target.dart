part of 'coach_food_host.dart';

extension _CoachFoodHostTarget on CoachFoodHost {
  Future<({Meal meal, MealItem item})?> _target(
    CoachFoodParsedTurn parsed, {
    required int? preferredTargetItemId,
    required String ownerKey,
  }) async {
    final candidateConcept = parsed.targetConcept?.trim().isNotEmpty == true
        ? parsed.targetConcept!.trim()
        : parsed.items.length == 1 &&
              parsed.items.single.concept.trim().isNotEmpty
        ? parsed.items.single.concept.trim()
        : null;
    if (candidateConcept == null && preferredTargetItemId != null) {
      try {
        final item = await meals.getMealItem(preferredTargetItemId);
        if (item.deletedAt != null) return null;
        final all = await meals.watchAll().first;
        for (final meal in all) {
          if (meal.meal.id == item.mealId) return (meal: meal.meal, item: item);
        }
      } on Object {
        return null;
      }
    }
    if (candidateConcept == null) return null;
    final wanted = normalizeFoodConcept(candidateConcept);
    final all = await meals.watchAll().first;
    final matches = <({Meal meal, MealItem item, DateTime rank})>[];
    for (final meal in all) {
      for (final item in meal.items) {
        final evidence = MealFoodEvidence.read(item, ownerKey: ownerKey);
        final names = <String>[
          ?evidence.portion?.food.name,
          ?meal.foodsById[item.foodId]?.name,
          ?meal.foodsById[item.foodId]?.arabicName,
        ];
        if (names.any((name) {
          final normalized = normalizeFoodConcept(name);
          return normalized == wanted ||
              normalized.contains(wanted) ||
              wanted.contains(normalized);
        })) {
          matches.add((meal: meal.meal, item: item, rank: item.updatedAt));
        }
      }
    }
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.rank.compareTo(a.rank));
    return (meal: matches.first.meal, item: matches.first.item);
  }
}
