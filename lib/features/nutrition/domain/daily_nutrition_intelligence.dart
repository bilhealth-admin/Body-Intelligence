import '../../../engine/nutrient_evidence_engine.dart';

class DailyNutritionTargets {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double sodium;
  final double potassium;
  final double waterMl;
  final List<String> sourceIds;

  const DailyNutritionTargets({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.waterMl,
    this.sourceIds = const <String>[],
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
  final bool caloriesKnown;
  final bool proteinKnown;
  final bool carbohydratesKnown;
  final bool fatKnown;
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
    this.caloriesKnown = true,
    this.proteinKnown = true,
    this.carbohydratesKnown = true,
    this.fatKnown = true,
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
  final List<String> sourceIds;

  const DailyNutritionInsight({
    required this.kind,
    required this.explanation,
    required this.action,
    this.sourceIds = const <String>[],
  });
}

class DailyNutritionReport {
  final int mealCount;
  final int itemCount;
  final NutrientEvidenceReport calorieEvidence;
  final NutrientEvidenceReport proteinEvidence;
  final NutrientEvidenceReport carbohydrateEvidence;
  final NutrientEvidenceReport fatEvidence;
  final NutrientEvidenceReport fiberEvidence;
  final NutrientEvidenceReport sodiumEvidence;
  final NutrientEvidenceReport potassiumEvidence;

  double? get calories => calorieEvidence.completeTotal;
  double? get protein => proteinEvidence.completeTotal;
  double? get carbohydrates => carbohydrateEvidence.completeTotal;
  double? get fat => fatEvidence.completeTotal;

  // Legacy secondary totals retain their explicit evidence flags. New consumers
  // use the reports above to distinguish complete intake from known subtotals.
  final double fiber;
  final double sodium;
  final double potassium;
  final int waterMl;
  final double? proteinEnergyShare;
  final double? carbohydrateEnergyShare;
  final double? fatEnergyShare;
  bool get fiberEvidenceComplete => fiberEvidence.completeTotal != null;
  bool get sodiumEvidenceComplete => sodiumEvidence.completeTotal != null;
  bool get potassiumEvidenceComplete => potassiumEvidence.completeTotal != null;
  final List<DailyNutritionInsight> insights;

  const DailyNutritionReport({
    required this.mealCount,
    required this.itemCount,
    required this.calorieEvidence,
    required this.proteinEvidence,
    required this.carbohydrateEvidence,
    required this.fatEvidence,
    required this.fiberEvidence,
    required this.sodiumEvidence,
    required this.potassiumEvidence,
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.waterMl,
    required this.proteinEnergyShare,
    required this.carbohydrateEnergyShare,
    required this.fatEnergyShare,
    required this.insights,
  });
}
