import '../domain/daily_nutrition_intelligence.dart';

class DailyNutritionIntelligenceEngine {
  const DailyNutritionIntelligenceEngine();

  DailyNutritionReport analyze({
    required Iterable<DailyNutritionItemSnapshot> items,
    required int mealCount,
    required int waterMl,
    required DailyNutritionTargets targets,
  }) {
    if (mealCount < 0) {
      throw ArgumentError.value(mealCount, 'mealCount', 'Must be non-negative');
    }
    if (waterMl < 0) {
      throw ArgumentError.value(waterMl, 'waterMl', 'Must be non-negative');
    }
    _validateTargets(targets);

    final materialized = List<DailyNutritionItemSnapshot>.unmodifiable(items);
    double calories = 0;
    double protein = 0;
    double carbohydrates = 0;
    double fat = 0;
    double fiber = 0;
    double sodium = 0;
    double potassium = 0;
    var fiberEvidenceComplete = materialized.isNotEmpty;
    var sodiumEvidenceComplete = materialized.isNotEmpty;
    var potassiumEvidenceComplete = materialized.isNotEmpty;

    for (final item in materialized) {
      _validateItem(item);
      calories += item.calories;
      protein += item.protein;
      carbohydrates += item.carbohydrates;
      fat += item.fat;
      fiber += item.fiber;
      sodium += item.sodium;
      potassium += item.potassium;
      fiberEvidenceComplete &= item.fiberKnown;
      sodiumEvidenceComplete &= item.sodiumKnown;
      potassiumEvidenceComplete &= item.potassiumKnown;
    }

    final macroEnergy = protein * 4 + carbohydrates * 4 + fat * 9;
    final proteinShare = macroEnergy > 0 ? protein * 4 / macroEnergy : null;
    final carbohydrateShare = macroEnergy > 0
        ? carbohydrates * 4 / macroEnergy
        : null;
    final fatShare = macroEnergy > 0 ? fat * 9 / macroEnergy : null;
    final insights = <DailyNutritionInsight>[];

    if (materialized.isEmpty) {
      insights.add(
        const DailyNutritionInsight(
          kind: DailyNutritionInsightKind.noMeals,
          explanation: 'No meal items are recorded for this day.',
          action: 'Log food before interpreting daily nutrition progress.',
        ),
      );
    } else {
      if (targets.calories > 0 && calories < targets.calories * 0.8) {
        insights.add(
          const DailyNutritionInsight(
            kind: DailyNutritionInsightKind.caloriesBelowTarget,
            explanation: 'Recorded calories are below 80% of the daily target.',
            action:
                'Review whether the day is incomplete before changing intake.',
          ),
        );
      } else if (targets.calories > 0 && calories > targets.calories * 1.1) {
        insights.add(
          const DailyNutritionInsight(
            kind: DailyNutritionInsightKind.caloriesAboveTarget,
            explanation:
                'Recorded calories are above 110% of the daily target.',
            action:
                'Review portions and logging accuracy without compensatory restriction.',
          ),
        );
      }
      if (targets.protein > 0 && protein < targets.protein * 0.8) {
        insights.add(
          const DailyNutritionInsight(
            kind: DailyNutritionInsightKind.proteinBelowTarget,
            explanation: 'Recorded protein is below 80% of the daily target.',
            action:
                'Consider an appropriate protein source if the day is still open.',
          ),
        );
      }
      if (fiberEvidenceComplete &&
          targets.fiber > 0 &&
          fiber < targets.fiber * 0.8) {
        insights.add(
          const DailyNutritionInsight(
            kind: DailyNutritionInsightKind.fiberBelowTarget,
            explanation: 'Known fiber is below 80% of the daily target.',
            action: 'Consider a suitable fiber-containing food if appropriate.',
          ),
        );
      }
      if (sodiumEvidenceComplete &&
          targets.sodium > 0 &&
          sodium > targets.sodium * 1.1) {
        insights.add(
          const DailyNutritionInsight(
            kind: DailyNutritionInsightKind.sodiumAboveTarget,
            explanation: 'Known sodium is above 110% of the configured target.',
            action:
                'Review sodium-dense foods and the completeness of the data.',
          ),
        );
      }
      if (potassiumEvidenceComplete &&
          targets.potassium > 0 &&
          potassium < targets.potassium * 0.8) {
        insights.add(
          const DailyNutritionInsight(
            kind: DailyNutritionInsightKind.potassiumBelowTarget,
            explanation:
                'Known potassium is below 80% of the configured target.',
            action:
                'Review food choices only if potassium data is complete and relevant.',
          ),
        );
      }
      if (!sodiumEvidenceComplete || !potassiumEvidenceComplete) {
        insights.add(
          const DailyNutritionInsight(
            kind: DailyNutritionInsightKind.incompleteElectrolyteEvidence,
            explanation:
                'Electrolyte values are incomplete for one or more foods.',
            action: 'Do not interpret missing electrolyte values as zero.',
          ),
        );
      }
    }

    if (targets.waterMl > 0 && waterMl < targets.waterMl * 0.8) {
      insights.add(
        const DailyNutritionInsight(
          kind: DailyNutritionInsightKind.hydrationBelowTarget,
          explanation: 'Recorded water is below 80% of the daily target.',
          action:
              'Review hydration logging and drink according to individual needs.',
        ),
      );
    }

    return DailyNutritionReport(
      mealCount: mealCount,
      itemCount: materialized.length,
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fat: fat,
      fiber: fiber,
      sodium: sodium,
      potassium: potassium,
      waterMl: waterMl,
      proteinEnergyShare: proteinShare,
      carbohydrateEnergyShare: carbohydrateShare,
      fatEnergyShare: fatShare,
      fiberEvidenceComplete: fiberEvidenceComplete,
      sodiumEvidenceComplete: sodiumEvidenceComplete,
      potassiumEvidenceComplete: potassiumEvidenceComplete,
      insights: List<DailyNutritionInsight>.unmodifiable(insights),
    );
  }

  void _validateTargets(DailyNutritionTargets targets) {
    final values = <double>[
      targets.calories,
      targets.protein,
      targets.carbohydrates,
      targets.fat,
      targets.fiber,
      targets.sodium,
      targets.potassium,
      targets.waterMl,
    ];
    if (values.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError(
        'Daily nutrition targets must be finite and non-negative.',
      );
    }
  }

  void _validateItem(DailyNutritionItemSnapshot item) {
    final values = <double>[
      item.calories,
      item.protein,
      item.carbohydrates,
      item.fat,
      item.fiber,
      item.sodium,
      item.potassium,
    ];
    if (values.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError(
        'Daily nutrition item values must be finite and non-negative.',
      );
    }
  }
}
