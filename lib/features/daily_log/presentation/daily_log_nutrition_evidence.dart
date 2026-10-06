import '../../../data/database/app_database.dart';
import '../../../data/database/meal_food_evidence.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';

/// Display totals use the immutable evidence belonging to each meal's owner.
/// A subtotal cannot stand in for a complete recorded total.
final class DailyLogNutritionEvidence {
  DailyLogNutritionEvidence._(Iterable<MealFoodEvidence> rows)
    : _rows = List.unmodifiable(rows);

  factory DailyLogNutritionEvidence.forMeals(Iterable<MealWithItems> meals) =>
      DailyLogNutritionEvidence._([
        for (final meal in meals)
          for (final item in meal.items)
            MealFoodEvidence.read(item, ownerKey: meal.ownerKey),
      ]);

  factory DailyLogNutritionEvidence.forItems(
    Iterable<MealItem> items, {
    String? ownerKey,
  }) => DailyLogNutritionEvidence._([
    for (final item in items) MealFoodEvidence.read(item, ownerKey: ownerKey),
  ]);

  final List<MealFoodEvidence> _rows;

  /// Empty core summaries can retain the existing zero-food state explicitly.
  /// Missing values in a recorded item always make the total unavailable.
  double? total(TrackedNutrient nutrient, {bool emptyAsZero = false}) {
    if (_rows.isEmpty) return emptyAsZero ? 0 : null;
    var sum = 0.0;
    for (final row in _rows) {
      final value = row.value(nutrient);
      if (value == null) return null;
      sum += value;
      if (!sum.isFinite) return null;
    }
    return sum;
  }

  double? get netCarbs {
    if (_rows.isEmpty) return null;
    var sum = 0.0;
    for (final row in _rows) {
      final value = netCarbohydrates(row);
      if (value == null) return null;
      sum += value;
      if (!sum.isFinite) return null;
    }
    return sum;
  }

  static double? netCarbohydrates(MealFoodEvidence row) {
    final carbs = row.value(TrackedNutrient.carbohydrates);
    final fiber = row.value(TrackedNutrient.fiber);
    if (carbs == null || fiber == null) return null;
    // Legacy fibre records can exceed total carbs; preserve the established
    // nonnegative display rule without treating an absent value as zero.
    return (carbs - fiber).clamp(0, double.infinity).toDouble();
  }
}
