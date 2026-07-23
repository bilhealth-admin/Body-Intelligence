import '../domain/meal_composition.dart';
import '../domain/unified_food.dart';
import 'nutrition_calculation_engine.dart';

class MealCompositionPolicy {
  final double minimumProteinEnergyShare;
  final double maximumFatEnergyShare;
  final double minimumFiberGramsPer1000Calories;
  final double maximumEnergyDensityPer100Grams;

  const MealCompositionPolicy({
    this.minimumProteinEnergyShare = 0.20,
    this.maximumFatEnergyShare = 0.45,
    this.minimumFiberGramsPer1000Calories = 10,
    this.maximumEnergyDensityPer100Grams = 250,
  });
}

class MealCompositionEngine {
  final NutritionCalculationEngine _nutritionEngine;
  final MealCompositionPolicy policy;

  const MealCompositionEngine({
    NutritionCalculationEngine nutritionEngine =
        const NutritionCalculationEngine(),
    this.policy = const MealCompositionPolicy(),
  }) : _nutritionEngine = nutritionEngine;

  MealCompositionReport analyze(Iterable<MealCompositionItem> items) {
    final materialized = List<MealCompositionItem>.unmodifiable(items);
    if (materialized.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'Meal must contain food items.',
      );
    }

    var totalGrams = 0.0;
    final sums = <FoodNutrient, double>{};
    final knownCounts = <FoodNutrient, int>{};

    for (final item in materialized) {
      if (!item.grams.isFinite || item.grams <= 0 || item.grams > 100000) {
        throw ArgumentError.value(
          item.grams,
          'grams',
          'Must be finite and greater than 0 up to 100000.',
        );
      }
      final portion = _nutritionEngine.calculate(
        food: item.food,
        grams: item.grams,
      );
      totalGrams += item.grams;
      for (final nutrient in FoodNutrient.values) {
        final amount = portion.nutrient(nutrient);
        if (!amount.isKnown) continue;
        sums[nutrient] = (sums[nutrient] ?? 0) + amount.value;
        knownCounts[nutrient] = (knownCounts[nutrient] ?? 0) + 1;
      }
    }

    final totals = <FoodNutrient, NutrientAmount>{
      for (final nutrient in FoodNutrient.values)
        nutrient: knownCounts.containsKey(nutrient)
            ? NutrientAmount.known(sums[nutrient] ?? 0)
            : const NutrientAmount.missing(),
    };

    final calories = totals[FoodNutrient.calories]!.nullableValue;
    final protein = totals[FoodNutrient.protein]!.nullableValue;
    final carbs = totals[FoodNutrient.carbohydrates]!.nullableValue;
    final fat = totals[FoodNutrient.fat]!.nullableValue;
    final fiber = totals[FoodNutrient.fiber]!.nullableValue;

    final macroEnergy = protein != null && carbs != null && fat != null
        ? protein * 4 + carbs * 4 + fat * 9
        : null;
    final proteinShare = macroEnergy != null && macroEnergy > 0
        ? protein! * 4 / macroEnergy
        : null;
    final carbohydrateShare = macroEnergy != null && macroEnergy > 0
        ? carbs! * 4 / macroEnergy
        : null;
    final fatShare = macroEnergy != null && macroEnergy > 0
        ? fat! * 9 / macroEnergy
        : null;
    final energyDensity = calories != null && totalGrams > 0
        ? calories / totalGrams * 100
        : null;
    final fiberDensity = calories != null && calories > 0 && fiber != null
        ? fiber / calories * 1000
        : null;

    final issues = <MealCompositionIssue>[];
    final suggestions = <MealCompositionSuggestion>[];

    if (calories == null) {
      issues.add(
        const MealCompositionIssue(
          kind: MealCompositionIssueKind.missingEnergyEvidence,
          explanation:
              'Energy density cannot be calculated because calorie evidence is missing.',
        ),
      );
    }
    if (macroEnergy == null) {
      issues.add(
        const MealCompositionIssue(
          kind: MealCompositionIssueKind.missingMacroEvidence,
          explanation:
              'Macro distribution cannot be calculated because one or more macro values are missing.',
        ),
      );
    }
    if (proteinShare != null &&
        proteinShare < policy.minimumProteinEnergyShare) {
      issues.add(
        const MealCompositionIssue(
          kind: MealCompositionIssueKind.lowProteinShare,
          explanation:
              'Protein contributes a relatively small share of known macro energy.',
        ),
      );
      suggestions.add(
        const MealCompositionSuggestion(
          code: 'consider-protein-source',
          explanation:
              'Consider adding a protein-rich food if that fits the user’s plan and preferences.',
        ),
      );
    }
    if (fatShare != null && fatShare > policy.maximumFatEnergyShare) {
      issues.add(
        const MealCompositionIssue(
          kind: MealCompositionIssueKind.highFatShare,
          explanation:
              'Fat contributes a relatively large share of known macro energy.',
        ),
      );
      suggestions.add(
        const MealCompositionSuggestion(
          code: 'review-fat-dense-items',
          explanation:
              'Review fat-dense ingredients and portions before changing the meal.',
        ),
      );
    }
    if (fiberDensity != null &&
        fiberDensity < policy.minimumFiberGramsPer1000Calories) {
      issues.add(
        const MealCompositionIssue(
          kind: MealCompositionIssueKind.lowFiberDensity,
          explanation:
              'Known fiber density is below the configured heuristic threshold.',
        ),
      );
      suggestions.add(
        const MealCompositionSuggestion(
          code: 'consider-fiber-source',
          explanation:
              'Consider a fiber-containing food if appropriate for the user.',
        ),
      );
    }
    if (energyDensity != null &&
        energyDensity > policy.maximumEnergyDensityPer100Grams) {
      issues.add(
        const MealCompositionIssue(
          kind: MealCompositionIssueKind.highEnergyDensity,
          explanation:
              'Energy density is above the configured heuristic threshold.',
        ),
      );
    }

    return MealCompositionReport(
      totalGrams: totalGrams,
      totals: Map<FoodNutrient, NutrientAmount>.unmodifiable(totals),
      proteinEnergyShare: proteinShare,
      carbohydrateEnergyShare: carbohydrateShare,
      fatEnergyShare: fatShare,
      energyDensityPer100Grams: energyDensity,
      fiberDensityPer1000Calories: fiberDensity,
      issues: List<MealCompositionIssue>.unmodifiable(issues),
      suggestions: List<MealCompositionSuggestion>.unmodifiable(suggestions),
    );
  }
}
