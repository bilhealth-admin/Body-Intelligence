import 'bil_smart_plan.dart';
import 'bil_smart_plan_engine.dart';

/// A quantity with external provenance: either one source-calculated recipe
/// serving, or an existing member-approved goal. Never calculated requirements.
final class BilPlanNutrients {
  BilPlanNutrients({required Map<String, double> values, required this.source})
    : values = Map.unmodifiable(values) {
    if (source.isEmpty ||
        values.isEmpty ||
        values.keys.any(
          (key) => !const {
            'kcal',
            'proteinG',
            'carbohydrateG',
            'fatG',
          }.contains(key),
        ) ||
        values.values.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('smart_plan_invalid_nutrients');
    }
  }
  final Map<String, double> values;
  final String source;

  static BilPlanNutrients? total(Iterable<BilPlanNutrients?> servings) {
    final items = servings.toList();
    if (items.isEmpty || items.any((item) => item == null)) return null;
    final keys = items.first!.values.keys.where(
      (key) => items.every((item) => item!.values.containsKey(key)),
    );
    final values = {
      for (final key in keys)
        key: items.fold<double>(0, (total, item) => total + item!.values[key]!),
    };
    return values.isEmpty
        ? null
        : BilPlanNutrients(values: values, source: 'verified_recipe_servings');
  }
}

/// A bounded search over existing, compatible recipes. Portions stay at one
/// documented serving; the selected plan is a suggestion, not a diary write or
/// an assertion that three meals exactly meet every nutritional requirement.
Map<BilPlanMealSlot, BilVerifiedRecipe> selectSmartPlanMeals({
  required Map<BilPlanMealSlot, List<BilVerifiedRecipe>> choices,
  required BilPlanNutrients? target,
  required Map<String, int> useCount,
  required int rotation,
}) {
  final fallback = {
    for (final slot in BilPlanMealSlot.values)
      slot: choices[slot]![rotation % choices[slot]!.length],
  };
  if (target == null || target.values['kcal'] == null) return fallback;
  var best = double.infinity;
  Map<BilPlanMealSlot, BilVerifiedRecipe>? selected;
  // The adapter supplies at most twelve source-verified choices per slot.
  for (final breakfast in choices[BilPlanMealSlot.breakfast]!.take(12)) {
    for (final lunch in choices[BilPlanMealSlot.lunch]!.take(12)) {
      for (final dinner in choices[BilPlanMealSlot.dinner]!.take(12)) {
        final recipes = [breakfast, lunch, dinner];
        final total = BilPlanNutrients.total(
          recipes.map((recipe) => recipe.nutrition),
        );
        if (total == null ||
            !target.values.keys.every(total.values.containsKey)) {
          continue;
        }
        var score = 0.0;
        for (final goal in target.values.entries) {
          if (goal.value <= 0) continue;
          score += (total.values[goal.key]! - goal.value).abs() / goal.value;
        }
        score += recipes.fold<double>(
          0,
          (sum, recipe) => sum + (useCount[recipe.id] ?? 0) * 0.03,
        );
        if (score < best) {
          best = score;
          selected = {
            BilPlanMealSlot.breakfast: breakfast,
            BilPlanMealSlot.lunch: lunch,
            BilPlanMealSlot.dinner: dinner,
          };
        }
      }
    }
  }
  return selected ?? fallback;
}
