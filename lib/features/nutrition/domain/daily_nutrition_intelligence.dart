class DailyNutritionTargets {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sodium;
  final double potassium;
  final double waterMl;

  const DailyNutritionTargets({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.waterMl,
  });
}

class DailyNutritionItemSnapshot {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sodium;
  final double potassium;
  final bool fiberKnown;
  final bool sodiumKnown;
  final bool potassiumKnown;

  const DailyNutritionItemSnapshot({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.fiberKnown,
    required this.sodiumKnown,
    required this.potassiumKnown,
  });
}

enum DailyNutritionInsightKind {
  noMeals,
  caloriesBelowTarget,
  caloriesAboveTarget,
  proteinBelowTarget,
  fiberBelowTarget,
  hydrationBelowTarget,
  sodiumAboveTarget,
  potassiumBelowTarget,
  incompleteElectrolyteEvidence,
}

class DailyNutritionInsight {
  final DailyNutritionInsightKind kind;
  final String explanation;
  final String action;

  const DailyNutritionInsight({
    required this.kind,
    required this.explanation,
    required this.action,
  });
}

class DailyNutritionReport {
  final int mealCount;
  final int itemCount;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sodium;
  final double potassium;
  final int waterMl;
  final double? proteinEnergyShare;
  final double? carbohydrateEnergyShare;
  final double? fatEnergyShare;
  final bool fiberEvidenceComplete;
  final bool sodiumEvidenceComplete;
  final bool potassiumEvidenceComplete;
  final List<DailyNutritionInsight> insights;

  const DailyNutritionReport({
    required this.mealCount,
    required this.itemCount,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.waterMl,
    required this.proteinEnergyShare,
    required this.carbohydrateEnergyShare,
    required this.fatEnergyShare,
    required this.fiberEvidenceComplete,
    required this.sodiumEvidenceComplete,
    required this.potassiumEvidenceComplete,
    required this.insights,
  });
}
