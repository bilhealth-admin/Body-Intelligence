import 'package:body_intelligence_log/features/nutrition/domain/serving_measure.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_unit_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/serving_intelligence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ServingIntelligenceEngine();
  const food = UnifiedFood(
    id: 'oats',
    name: 'Oats',
    serving: FoodServing(amount: 100, unit: 'g', grams: 100),
    nutrients: <FoodNutrient, NutrientAmount>{
      FoodNutrient.calories: NutrientAmount.known(400),
      FoodNutrient.protein: NutrientAmount.known(20),
      FoodNutrient.sodium: NutrientAmount.known(0),
      FoodNutrient.fiber: NutrientAmount.missing(),
    },
    source: FoodDataSource.foundation,
    sourceLabel: 'foundation',
    verified: true,
    isCustom: false,
  );

  test('mass units resolve to grams and nutrition deterministically', () {
    final grams = engine.calculateMass(food: food, quantity: 50, unit: 'g');
    expect(grams.grams, 50);
    expect(grams.nutrition.knownValue(FoodNutrient.calories), 200);

    final kilograms = engine.calculateMass(
      food: food,
      quantity: 0.05,
      unit: 'kg',
    );
    expect(kilograms.grams, 50);
    expect(kilograms.nutrition.knownValue(FoodNutrient.protein), 10);
  });

  test('ounce and pound conversions reuse the unit engine contract', () {
    final ounce = engine.calculateMass(food: food, quantity: 1, unit: 'oz');
    expect(ounce.grams, closeTo(FoodUnitEngine.gramsPerOunce, 1e-9));

    final pound = engine.calculateMass(food: food, quantity: 1, unit: 'lb');
    expect(pound.grams, closeTo(FoodUnitEngine.gramsPerPound, 1e-9));
  });

  test('default food serving can be scaled by count', () {
    final result = engine.calculateFoodServing(food: food, count: 0.5);
    expect(result.grams, 50);
    expect(result.nutrition.knownValue(FoodNutrient.calories), 200);
  });

  test('defined household serving converts through its gram weight', () {
    const cup = ServingMeasure(
      id: 'cup',
      label: 'cup',
      amount: 1,
      unit: 'cup',
      grams: 80,
    );
    final result = engine.calculateDefinedServing(
      food: food,
      count: 1.5,
      serving: cup,
    );
    expect(result.grams, 120);
    expect(result.nutrition.knownValue(FoodNutrient.calories), 480);
  });

  test('known zero and missing nutrients remain distinct', () {
    final result = engine.calculateMass(food: food, quantity: 25, unit: 'g');
    expect(result.nutrition.knownValue(FoodNutrient.sodium), 0);
    expect(result.nutrition.knownValue(FoodNutrient.fiber), isNull);
  });

  test('invalid quantities and unsupported units fail explicitly', () {
    expect(
      () => engine.calculateMass(food: food, quantity: 0, unit: 'g'),
      throwsArgumentError,
    );
    expect(
      () => engine.calculateMass(food: food, quantity: 1, unit: 'cup'),
      throwsArgumentError,
    );
  });

  test('serving options are stable, filtered, and deduplicated', () {
    const cup = ServingMeasure(
      id: 'cup',
      label: 'cup',
      amount: 1,
      unit: 'cup',
      grams: 80,
    );
    const duplicateCup = ServingMeasure(
      id: 'cup',
      label: 'another cup',
      amount: 1,
      unit: 'cup',
      grams: 90,
    );
    const invalid = ServingMeasure(
      id: '',
      label: 'invalid',
      amount: 1,
      unit: 'piece',
      grams: 10,
    );
    final options = engine.optionsFor(
      food,
      additional: const <ServingMeasure>[cup, duplicateCup, invalid],
    );
    expect(options, hasLength(2));
    expect(options.last.id, 'cup');
    expect(options.last.grams, 80);
  });
}
