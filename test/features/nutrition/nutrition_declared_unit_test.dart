import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/services/nutrition_calculation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

UnifiedFood _label({
  String unit = 'ml',
  double amount = 100,
  double grams = 0,
  Map<FoodNutrient, NutrientAmount>? nutrients,
}) => UnifiedFood(
  id: 'synthetic-label',
  name: 'Synthetic nutrition label',
  serving: FoodServing(amount: amount, unit: unit, grams: grams),
  nutrients:
      nutrients ??
      const {
        FoodNutrient.calories: NutrientAmount.known(50),
        FoodNutrient.protein: NutrientAmount.known(0),
        FoodNutrient.fiber: NutrientAmount.missing(),
        FoodNutrient.iron: NutrientAmount.known(2),
      },
  source: FoodDataSource.custom,
  sourceLabel: 'synthetic-label',
  verified: false,
  isCustom: true,
);

void main() {
  const engine = NutritionCalculationEngine();
  for (final unit in ['ml', 'piece', 'entry', 'cup']) {
    test('$unit scales within its label unit without inventing gram mass', () {
      final portion = engine.calculateServingUnits(
        food: _label(unit: unit, amount: 2),
        amount: 3,
        unit: unit,
      );
      expect(portion.grams, isNull);
      expect(portion.knownValue(FoodNutrient.calories), 75);
      expect(portion.knownValue(FoodNutrient.protein), 0);
      expect(portion.knownValue(FoodNutrient.fiber), isNull);
      expect(portion.knownValue(FoodNutrient.iron), 3);
      expect(portion.knownValue(FoodNutrient.vitaminC), isNull);
    });

    test('$unit cannot supply a gram calculation without mass evidence', () {
      expect(
        () => engine.calculate(food: _label(unit: unit), grams: 150),
        throwsStateError,
      );
    });
  }

  test(
    'declared kg serving keeps the same nutrition ratio and measured mass',
    () {
      final portion = engine.calculateServingUnits(
        food: _label(unit: 'kg', amount: .25, grams: 250),
        amount: .5,
        unit: 'kg',
      );
      expect(portion.grams, 500);
      expect(portion.knownValue(FoodNutrient.calories), 100);
      expect(portion.knownValue(FoodNutrient.iron), 4);
    },
  );

  test('a declared-unit request cannot silently convert ml to g', () {
    expect(
      () =>
          engine.calculateServingUnits(food: _label(), amount: 150, unit: 'g'),
      throwsArgumentError,
    );
  });

  for (final amount in [0.0, -1.0, double.nan, double.infinity, 100001.0]) {
    test('invalid declared quantity $amount is rejected', () {
      expect(
        () => engine.calculateServingUnits(
          food: _label(),
          amount: amount,
          unit: 'ml',
        ),
        throwsArgumentError,
      );
    });
  }

  test('overflowing basis cannot hide behind entirely unknown nutrients', () {
    expect(
      () => engine.calculateServingUnits(
        food: _label(amount: 1e-308, nutrients: {}),
        amount: 100000,
        unit: 'ml',
      ),
      throwsStateError,
    );
  });

  for (final value in [-1.0, double.nan, double.infinity, 1e308]) {
    test('invalid or overflowing known label nutrition $value is rejected', () {
      expect(
        () => engine.calculateServingUnits(
          food: _label(
            nutrients: {FoodNutrient.calories: NutrientAmount.known(value)},
          ),
          amount: 1000,
          unit: 'ml',
        ),
        throwsStateError,
      );
    });
  }
}
