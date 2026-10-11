part of 'nutrition_analytics_page.dart';

class NutritionAnalyticsTotals {
  const NutritionAnalyticsTotals({
    required this.values,
    required this.knownCounts,
    required this.unknownCounts,
    this.fullValues = const {},
    this.fullKnownCounts = const {},
    this.fullUnknownCounts = const {},
  });
  final Map<FoodNutrient, double> fullValues;
  final Map<FoodNutrient, int> fullKnownCounts, fullUnknownCounts;
  double? fullTotal(FoodNutrient n) =>
      (fullKnownCounts[n] ?? 0) > 0 ? fullValues[n] : null;
  bool fullComplete(FoodNutrient n) =>
      (fullKnownCounts[n] ?? 0) > 0 && (fullUnknownCounts[n] ?? 0) == 0;
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
    final items = [
      for (final meal in meals)
        for (final item in meal.items)
          MealFoodEvidence.read(item, ownerKey: meal.ownerKey),
    ];
    final values = <TrackedNutrient, double>{};
    final known = <TrackedNutrient, int>{};
    final unknown = <TrackedNutrient, int>{};
    for (final nutrient in TrackedNutrient.values) {
      var total = 0.0;
      var knownCount = 0;
      var unknownCount = 0;
      for (final item in items) {
        final amount = item.value(nutrient);
        if (amount == null || !amount.isFinite || amount < 0) {
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
    final fullValues = <FoodNutrient, double>{};
    final fullKnown = <FoodNutrient, int>{};
    final fullUnknown = <FoodNutrient, int>{};
    for (final nutrient in FoodNutrient.values) {
      var total = 0.0, known = 0, unknown = 0;
      for (final item in items) {
        final value = item.fullValue(nutrient);
        if (value == null) {
          unknown++;
        } else {
          total += value;
          known++;
        }
      }
      fullValues[nutrient] = total;
      fullKnown[nutrient] = known;
      fullUnknown[nutrient] = unknown;
    }
    return NutritionAnalyticsTotals(
      values: Map.unmodifiable(values),
      knownCounts: Map.unmodifiable(known),
      unknownCounts: Map.unmodifiable(unknown),
      fullValues: Map.unmodifiable(fullValues),
      fullKnownCounts: Map.unmodifiable(fullKnown),
      fullUnknownCounts: Map.unmodifiable(fullUnknown),
    );
  }
}

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
