import '../../../data/database/nutrient_evidence.dart';
import '../domain/unified_food.dart';
import 'gram_engine.dart';

class NutritionPortion {
  final double grams;
  final Map<FoodNutrient, NutrientAmount> nutrients;

  const NutritionPortion({required this.grams, required this.nutrients});

  NutrientAmount nutrient(FoodNutrient nutrient) =>
      nutrients[nutrient] ?? const NutrientAmount.missing();

  double valueOrZero(FoodNutrient nutrient) => this.nutrient(nutrient).value;

  double? knownValue(FoodNutrient nutrient) =>
      this.nutrient(nutrient).nullableValue;

  int get nutrientEvidenceMask => NutrientEvidenceMask.fromValues(
    calories: knownValue(FoodNutrient.calories),
    protein: knownValue(FoodNutrient.protein),
    carbohydrates: knownValue(FoodNutrient.carbohydrates),
    fat: knownValue(FoodNutrient.fat),
    fiber: knownValue(FoodNutrient.fiber),
    sugar: knownValue(FoodNutrient.sugar),
    sodium: knownValue(FoodNutrient.sodium),
    potassium: knownValue(FoodNutrient.potassium),
    calcium: knownValue(FoodNutrient.calcium),
    magnesium: knownValue(FoodNutrient.magnesium),
    phosphorus: knownValue(FoodNutrient.phosphorus),
  );
}

class NutritionCalculationEngine {
  const NutritionCalculationEngine();

  NutritionPortion calculate({
    required UnifiedFood food,
    required double grams,
  }) {
    if (!grams.isFinite || grams <= 0 || grams > 100000) {
      throw ArgumentError.value(
        grams,
        'grams',
        'Must be finite and greater than 0 up to 100000',
      );
    }
    if (!food.serving.grams.isFinite || food.serving.grams <= 0) {
      throw StateError('Food ${food.id} has an invalid gram basis');
    }

    return NutritionPortion(
      grams: grams,
      nutrients: Map<FoodNutrient, NutrientAmount>.unmodifiable(
        GramEngine.scaleNutrients(
          nutrients: food.nutrients,
          grams: grams,
          basisGrams: food.serving.grams,
        ),
      ),
    );
  }
}
