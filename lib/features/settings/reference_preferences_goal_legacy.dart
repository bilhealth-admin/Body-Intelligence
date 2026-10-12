part of 'reference_preferences_pages.dart';

typedef MacroPercentages = ({double carbs, double protein, double fat});

String _formatNutritionGoalNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

MacroPercentages normalizeMacroPercentages({double? carbs, double? fat}) {
  final carbsAnchor = carbs;
  final fatAnchor = fat;
  if (carbsAnchor == null ||
      fatAnchor == null ||
      !carbsAnchor.isFinite ||
      !fatAnchor.isFinite ||
      carbsAnchor < 0 ||
      fatAnchor < 0 ||
      carbsAnchor > 100 ||
      fatAnchor > 100 ||
      carbsAnchor + fatAnchor > 100) {
    return (carbs: 45, protein: 30, fat: 25);
  }
  return (
    carbs: carbsAnchor,
    protein: 100 - carbsAnchor - fatAnchor,
    fat: fatAnchor,
  );
}

Map<String, String> nutritionGoalSnapshotForCalories({
  required double calories,
  double? carbsPercent,
  double? fatPercent,
}) {
  final macros = normalizeMacroPercentages(
    carbs: carbsPercent,
    fat: fatPercent,
  );
  return {
    'goal.calories': _formatNutritionGoalNumber(calories),
    'goal.carbsPercent': _formatNutritionGoalNumber(macros.carbs),
    'goal.proteinPercent': _formatNutritionGoalNumber(macros.protein),
    'goal.fatPercent': _formatNutritionGoalNumber(macros.fat),
    'goal.carbsGrams': _formatNutritionGoalNumber(
      calories * macros.carbs / 400,
    ),
    'goal.proteinGrams': _formatNutritionGoalNumber(
      calories * macros.protein / 400,
    ),
    'goal.fatGrams': _formatNutritionGoalNumber(calories * macros.fat / 900),
  };
}

/// Returns the canonical seven-key nutrition goal when a persisted snapshot
/// needs repair, otherwise `null`.
///
/// Older builds allowed independently saved macro percentages, so an upgrade
/// can contain totals above 100% or percentages without their derived grams.
/// Carbohydrate and fat are the user's anchors and protein is the remainder.
@visibleForTesting
Map<String, String>? nutritionGoalRepairSnapshot(Map<String, String?> stored) {
  final calories = double.tryParse(stored['goal.calories'] ?? '');
  if (calories == null ||
      !calories.isFinite ||
      calories < 1 ||
      calories > 10000) {
    return null;
  }
  if (stored['goal.macroEditor.v2'] == 'true') return null;
  final canonical = nutritionGoalSnapshotForCalories(
    calories: calories,
    carbsPercent: double.tryParse(stored['goal.carbsPercent'] ?? ''),
    fatPercent: double.tryParse(stored['goal.fatPercent'] ?? ''),
  );
  final unchanged = canonical.entries.every(
    (entry) => stored[entry.key] == entry.value,
  );
  return unchanged ? null : canonical;
}
