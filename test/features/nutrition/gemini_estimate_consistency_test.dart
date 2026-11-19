import 'package:body_intelligence_log/features/nutrition/domain/gemini_vision_estimate.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:flutter_test/flutter_test.dart';

GeminiVisionEstimate estimate(
  Map<FoodNutrient, double?> values, {
  String unit = 'g',
  double amount = 100,
}) => GeminiVisionEstimate(
  requestId: 'consistency',
  index: 0,
  name: 'Visible meal',
  modelRevision: 'gemini-test',
  promptRevision: 'photo-test',
  nutrients: GeminiEstimateNutrients(values, netCarbohydrates: null),
  basis: GeminiEstimateBasis(quantity: amount, unit: unit),
  picturedAmount: amount,
  picturedUnit: unit,
);
void main() {
  test(
    'gram mass and contained component counterexamples cannot become saved evidence',
    () {
      for (final values in [
        {
          FoodNutrient.protein: 80.0,
          FoodNutrient.carbohydrates: 80.0,
          FoodNutrient.fat: 80.0,
        },
        {FoodNutrient.protein: 80.0, FoodNutrient.carbohydrates: 80.0},
        {FoodNutrient.fat: 0.0, FoodNutrient.saturatedFat: 10.0},
        {
          FoodNutrient.carbohydrates: 10.0,
          FoodNutrient.fiber: 8.0,
          FoodNutrient.sugar: 9.0,
        },
      ]) {
        expect(() => estimate(values), throwsFormatException);
      }
    },
  );
  test(
    'near rounding and trans overlap are accepted without manufacturing calories',
    () {
      final result = estimate({
        FoodNutrient.protein: 30,
        FoodNutrient.carbohydrates: 40,
        FoodNutrient.fat: 31,
        FoodNutrient.fiber: 5,
        FoodNutrient.sugar: 35.1,
        FoodNutrient.saturatedFat: 5,
        FoodNutrient.monounsaturatedFat: 20,
        FoodNutrient.polyunsaturatedFat: 5,
        FoodNutrient.transFat: 3,
      });
      expect(result.nutrients[FoodNutrient.calories], isNull);
      expect(result.nutrients[FoodNutrient.fat], 31);
      expect(result.nutrients[FoodNutrient.transFat], 3);
    },
  );
  test('count or volume estimates do not acquire gram mass assumptions', () {
    for (final unit in ['piece', 'ml']) {
      final result = estimate(
        {
          FoodNutrient.protein: 80,
          FoodNutrient.carbohydrates: 80,
          FoodNutrient.fat: 80,
        },
        unit: unit,
        amount: 1,
      );
      expect(result.basis!.unit, unit);
    }
  });
}
