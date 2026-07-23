import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/explainable_nutrition_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ExplainableNutritionEngine();

  test(
    'explains known and missing nutrients without converting missing to zero',
    () {
      const food = UnifiedFood(
        id: 'foundation:oats',
        name: 'Oats',
        serving: FoodServing(amount: 100, unit: 'g', grams: 100),
        nutrients: <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: NutrientAmount.known(389),
          FoodNutrient.protein: NutrientAmount.known(16.9),
          FoodNutrient.sodium: NutrientAmount.known(0),
          FoodNutrient.magnesium: NutrientAmount.missing(),
        },
        source: FoodDataSource.foundation,
        sourceLabel: 'foundation',
        verified: true,
        isCustom: false,
      );

      final report = engine.explain(food: food, grams: 50);
      final calories = report.explanationFor(FoodNutrient.calories);
      final sodium = report.explanationFor(FoodNutrient.sodium);
      final magnesium = report.explanationFor(FoodNutrient.magnesium);

      expect(report.origin, NutritionValueOrigin.foundation);
      expect(calories.calculatedValue, closeTo(194.5, 0.001));
      expect(calories.calculationFactor, 0.5);
      expect(sodium.isKnown, isTrue);
      expect(sodium.calculatedValue, 0);
      expect(magnesium.isKnown, isFalse);
      expect(magnesium.calculatedValue, isNull);
      expect(magnesium.reasons, contains('missing-is-not-zero'));
    },
  );

  test('identifies OpenFoodFacts provenance explicitly', () {
    const food = UnifiedFood(
      id: 'openfoodfacts:12345670',
      name: 'Imported yogurt',
      serving: FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: NutrientAmount.known(96),
      },
      source: FoodDataSource.branded,
      sourceLabel: 'openfoodfacts',
      verified: false,
      isCustom: false,
    );

    final report = engine.explain(food: food);

    expect(report.origin, NutritionValueOrigin.openFoodFacts);
    expect(report.summaryReasons, contains('source:openFoodFacts'));
    expect(report.summaryReasons, contains('source-record-is-unverified'));
  });

  test('custom food provenance and Arabic display name remain explainable', () {
    const food = UnifiedFood(
      id: 'custom:1',
      name: 'Personal meal',
      arabicName: 'وجبتي',
      serving: FoodServing(amount: 1, unit: 'serving', grams: 250),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.protein: NutrientAmount.known(30),
      },
      source: FoodDataSource.custom,
      sourceLabel: 'custom',
      verified: false,
      isCustom: true,
    );

    final report = engine.explain(food: food, grams: 125);

    expect(report.foodName, 'وجبتي');
    expect(report.origin, NutritionValueOrigin.custom);
    expect(
      report.explanationFor(FoodNutrient.protein).calculatedValue,
      closeTo(15, 0.001),
    );
  });

  test('rejects invalid requested gram quantities', () {
    const food = UnifiedFood(
      id: 'foundation:test',
      name: 'Test food',
      serving: FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{},
      source: FoodDataSource.foundation,
      sourceLabel: 'foundation',
      verified: true,
      isCustom: false,
    );

    expect(() => engine.explain(food: food, grams: 0), throwsArgumentError);
    expect(
      () => engine.explain(food: food, grams: double.nan),
      throwsArgumentError,
    );
  });
}
