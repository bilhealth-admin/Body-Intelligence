part of 'nutrition_analytics_page.dart';

class NutritionAnalyticsTotals {
  const NutritionAnalyticsTotals({
    required this.values,
    required this.knownCounts,
    required this.unknownCounts,
  });
  final Map<TrackedNutrient, double> values;
  final Map<TrackedNutrient, int> knownCounts;
  final Map<TrackedNutrient, int> unknownCounts;

  double value(TrackedNutrient nutrient) => values[nutrient] ?? 0;
  bool isKnown(TrackedNutrient nutrient) => (knownCounts[nutrient] ?? 0) > 0;
  bool isComplete(TrackedNutrient nutrient) =>
      isKnown(nutrient) && (unknownCounts[nutrient] ?? 0) == 0;

  double get calories => value(TrackedNutrient.calories);
  double get protein => value(TrackedNutrient.protein);
  double get carbs => value(TrackedNutrient.carbohydrates);
  double get fats => value(TrackedNutrient.fat);
  double get fiber => value(TrackedNutrient.fiber);
  double get sugar => value(TrackedNutrient.sugar);
  double get sodium => value(TrackedNutrient.sodium);
  double get potassium => value(TrackedNutrient.potassium);
  double get calcium => value(TrackedNutrient.calcium);
  double get magnesium => value(TrackedNutrient.magnesium);
  double get phosphorus => value(TrackedNutrient.phosphorus);

  factory NutritionAnalyticsTotals.fromMeals(List<MealWithItems> meals) {
    final items = meals.expand((meal) => meal.items).toList(growable: false);
    final values = <TrackedNutrient, double>{};
    final known = <TrackedNutrient, int>{};
    final unknown = <TrackedNutrient, int>{};
    for (final nutrient in TrackedNutrient.values) {
      var total = 0.0;
      var knownCount = 0;
      var unknownCount = 0;
      for (final item in items) {
        final amount = _itemNutrientValue(item, nutrient);
        final evidenced = NutrientEvidenceMask.contains(
          item.nutrientEvidenceMask,
          nutrient,
        );
        if (!evidenced || !amount.isFinite || amount < 0) {
          unknownCount++;
          continue;
        }
        total += amount;
        knownCount++;
      }
      values[nutrient] = total;
      known[nutrient] = knownCount;
      unknown[nutrient] = unknownCount;
    }
    return NutritionAnalyticsTotals(
      values: Map.unmodifiable(values),
      knownCounts: Map.unmodifiable(known),
      unknownCounts: Map.unmodifiable(unknown),
    );
  }
}

double _itemNutrientValue(MealItem item, TrackedNutrient nutrient) =>
    switch (nutrient) {
      TrackedNutrient.calories => item.calories,
      TrackedNutrient.protein => item.protein,
      TrackedNutrient.carbohydrates => item.carbs,
      TrackedNutrient.fat => item.fats,
      TrackedNutrient.fiber => item.fiber,
      TrackedNutrient.sugar => item.sugar,
      TrackedNutrient.sodium => item.sodium,
      TrackedNutrient.potassium => item.potassium,
      TrackedNutrient.calcium => item.calcium,
      TrackedNutrient.magnesium => item.magnesium,
      TrackedNutrient.phosphorus => item.phosphorus,
    };

class _NutritionTargets {
  const _NutritionTargets({
    this.calories,
    this.protein,
    this.carbs,
    this.fats,
    this.fiber,
  });
  final double? calories, protein, carbs, fats, fiber;
  factory _NutritionTargets.from(
    DailyTargets recommended, {
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
    int? fiber,
  }) => _NutritionTargets(
    calories: (calories ?? recommended.calories).toDouble(),
    protein: (protein ?? recommended.protein).toDouble(),
    carbs: (carbs ?? recommended.carbs).toDouble(),
    fats: (fats ?? recommended.fats).toDouble(),
    fiber: (fiber ?? recommended.fiber).toDouble(),
  );
}
