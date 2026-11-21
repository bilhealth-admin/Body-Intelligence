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
  final fallback = _diverseMealFallback(choices, rotation);
  if (target == null || target.values['kcal'] == null) return fallback;
  var best = double.infinity;
  Map<BilPlanMealSlot, BilVerifiedRecipe>? selected;
  BilPlanNutrients? selectedNutrients;
  var selectedDistinct = 0;
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
        final distinct = recipes.map((recipe) => recipe.id).toSet().length;
        // Variety only breaks a true tie: neither the existing objective nor
        // any source-backed nutrient total may worsen for a saved target.
        final priorNutrients = selectedNutrients;
        final sameNutrients =
            priorNutrients != null &&
            total.values.length == priorNutrients.values.length &&
            total.values.entries.every(
              (entry) => priorNutrients.values[entry.key] == entry.value,
            );
        if (score < best ||
            (score == best && distinct > selectedDistinct && sameNutrients)) {
          best = score;
          selectedNutrients = total;
          selectedDistinct = distinct;
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

/// Keep the rotated first choices when already distinct. Otherwise search only
/// the same eligible, bounded pool; scarce pools still fill every meal slot.
/// This affects a newly generated suggestion, never a stored plan or portion.
Map<BilPlanMealSlot, BilVerifiedRecipe> _diverseMealFallback(
  Map<BilPlanMealSlot, List<BilVerifiedRecipe>> choices,
  int rotation,
) {
  Iterable<BilVerifiedRecipe> rotated(BilPlanMealSlot slot) sync* {
    final rows = choices[slot]!;
    for (var offset = 0; offset < rows.length && offset < 12; offset++) {
      yield rows[(rotation + offset) % rows.length];
    }
  }

  var selected = {
    for (final slot in BilPlanMealSlot.values)
      slot: choices[slot]![rotation % choices[slot]!.length],
  };
  var distinct = selected.values.map((recipe) => recipe.id).toSet().length;
  if (distinct == BilPlanMealSlot.values.length) return selected;
  for (final breakfast in rotated(BilPlanMealSlot.breakfast)) {
    for (final lunch in rotated(BilPlanMealSlot.lunch)) {
      for (final dinner in rotated(BilPlanMealSlot.dinner)) {
        final count = {breakfast.id, lunch.id, dinner.id}.length;
        if (count <= distinct) continue;
        distinct = count;
        selected = {
          BilPlanMealSlot.breakfast: breakfast,
          BilPlanMealSlot.lunch: lunch,
          BilPlanMealSlot.dinner: dinner,
        };
        if (distinct == BilPlanMealSlot.values.length) return selected;
      }
    }
  }
  return selected;
}
