import 'package:body_intelligence_log/features/nutrition/domain/meal_composition.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_composition_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = MealCompositionEngine();

  const balanced = UnifiedFood(
    id: 'balanced',
    name: 'Balanced food',
    serving: FoodServing(amount: 100, unit: 'g', grams: 100),
    nutrients: <FoodNutrient, NutrientAmount>{
      FoodNutrient.calories: NutrientAmount.known(200),
      FoodNutrient.protein: NutrientAmount.known(20),
      FoodNutrient.carbohydrates: NutrientAmount.known(20),
      FoodNutrient.fat: NutrientAmount.known(4),
      FoodNutrient.fiber: NutrientAmount.known(4),
    },
    source: FoodDataSource.foundation,
    sourceLabel: 'foundation',
    verified: true,
    isCustom: false,
  );

  test('aggregates portions deterministically and exposes densities', () {
    final report = engine.analyze(const <MealCompositionItem>[
      MealCompositionItem(food: balanced, grams: 150),
      MealCompositionItem(food: balanced, grams: 50),
    ]);

    expect(report.totalGrams, 200);
    expect(report.nutrient(FoodNutrient.calories).value, 400);
    expect(report.nutrient(FoodNutrient.protein).value, 40);
    expect(report.energyDensityPer100Grams, 200);
    expect(report.fiberDensityPer1000Calories, 20);
    expect(report.proteinEnergyShare, closeTo(160 / 392, 0.0001));
  });

  test('preserves missing evidence instead of converting it to zero', () {
    const incomplete = UnifiedFood(
      id: 'incomplete',
      name: 'Incomplete food',
      serving: FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.protein: NutrientAmount.known(10),
      },
      source: FoodDataSource.custom,
      sourceLabel: 'custom',
      verified: false,
      isCustom: true,
    );

    final report = engine.analyze(const <MealCompositionItem>[
      MealCompositionItem(food: incomplete, grams: 100),
    ]);

    expect(report.nutrient(FoodNutrient.calories).isKnown, isFalse);
    expect(report.energyDensityPer100Grams, isNull);
    expect(
      report.issues.map((issue) => issue.kind),
      contains(MealCompositionIssueKind.missingEnergyEvidence),
    );
  });

  test('recommendations are explanatory, deterministic, and read-only', () {
    const lowProtein = UnifiedFood(
      id: 'low-protein',
      name: 'Low protein meal component',
      serving: FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: NutrientAmount.known(300),
        FoodNutrient.protein: NutrientAmount.known(5),
        FoodNutrient.carbohydrates: NutrientAmount.known(40),
        FoodNutrient.fat: NutrientAmount.known(14),
        FoodNutrient.fiber: NutrientAmount.known(1),
      },
      source: FoodDataSource.branded,
      sourceLabel: 'branded',
      verified: false,
      isCustom: false,
    );

    final first = engine.analyze(const <MealCompositionItem>[
      MealCompositionItem(food: lowProtein, grams: 100),
    ]);
    final second = engine.analyze(const <MealCompositionItem>[
      MealCompositionItem(food: lowProtein, grams: 100),
    ]);

    expect(
      first.issues.map((issue) => issue.kind),
      contains(MealCompositionIssueKind.lowProteinShare),
    );
    expect(
      first.suggestions.map((suggestion) => suggestion.code),
      contains('consider-protein-source'),
    );
    expect(
      second.suggestions.map((suggestion) => suggestion.code).toList(),
      first.suggestions.map((suggestion) => suggestion.code).toList(),
    );
  });

  test('rejects invalid or empty input', () {
    expect(
      () => engine.analyze(const <MealCompositionItem>[]),
      throwsArgumentError,
    );
    expect(
      () => engine.analyze(const <MealCompositionItem>[
        MealCompositionItem(food: balanced, grams: double.nan),
      ]),
      throwsArgumentError,
    );
  });
}
