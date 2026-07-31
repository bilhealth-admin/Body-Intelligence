import 'unified_food.dart';

class MealCompositionItem {
  final UnifiedFood food;
  final double grams;

  const MealCompositionItem({required this.food, required this.grams});
}

enum MealCompositionIssueKind {
  missingEnergyEvidence,
  missingMacroEvidence,
  lowProteinShare,
  highFatShare,
  lowFiberDensity,
  highEnergyDensity,
}

class MealCompositionIssue {
  final MealCompositionIssueKind kind;
  final String explanation;

  const MealCompositionIssue({required this.kind, required this.explanation});
}

class MealCompositionSuggestion {
  final String code;
  final String explanation;

  const MealCompositionSuggestion({
    required this.code,
    required this.explanation,
  });
}

class MealCompositionReport {
  final double totalGrams;
  final Map<FoodNutrient, NutrientAmount> totals;
  final double? proteinEnergyShare;
  final double? carbohydrateEnergyShare;
  final double? fatEnergyShare;
  final double? energyDensityPer100Grams;
  final double? fiberDensityPer1000Calories;
  final List<MealCompositionIssue> issues;
  final List<MealCompositionSuggestion> suggestions;

  const MealCompositionReport({
    required this.totalGrams,
    required this.totals,
    required this.proteinEnergyShare,
    required this.carbohydrateEnergyShare,
    required this.fatEnergyShare,
    required this.energyDensityPer100Grams,
    required this.fiberDensityPer1000Calories,
    required this.issues,
    required this.suggestions,
  });

  NutrientAmount nutrient(FoodNutrient nutrient) =>
      totals[nutrient] ?? const NutrientAmount.missing();
}
