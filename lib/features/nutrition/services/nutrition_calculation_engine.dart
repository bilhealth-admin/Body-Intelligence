import '../../../data/database/nutrient_evidence.dart';
import '../domain/unified_food.dart';
import 'gram_engine.dart';

class NutritionPortion {
  /// Null for a declared volume/count serving without a measured mass basis.
  final double? grams;
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

  /// Scales a label within its explicitly declared unit. This does not convert
  /// millilitres, pieces or servings to grams when their mass is unknown.
  NutritionPortion calculateServingUnits({
    required UnifiedFood food,
    required double amount,
    required String unit,
  }) {
    final normalized = unit.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized != food.serving.unit.trim().toLowerCase()) {
      throw ArgumentError('A serving quantity must use its label unit');
    }
    if (!amount.isFinite ||
        amount <= 0 ||
        amount > 100000 ||
        !food.serving.amount.isFinite ||
        food.serving.amount <= 0) {
      throw ArgumentError('Invalid declared serving amount');
    }
    final ratio = amount / food.serving.amount;
    final mass = food.serving.grams;
    if (!ratio.isFinite || ratio <= 0 || !mass.isFinite || mass < 0) {
      throw StateError('Invalid declared serving basis');
    }
    final grams = mass > 0 ? mass * ratio : null;
    if (grams != null && !grams.isFinite) {
      throw StateError('Declared serving mass exceeds the calculation range');
    }
    return NutritionPortion(
      grams: grams,
      nutrients: Map.unmodifiable({
        for (final nutrient in FoodNutrient.values)
          nutrient: food.nutrient(nutrient).isKnown
              ? _scaledDeclaredNutrient(food.nutrient(nutrient).value, ratio)
              : const NutrientAmount.missing(),
      }),
    );
  }

  NutrientAmount _scaledDeclaredNutrient(double value, double ratio) {
    final scaled = value * ratio;
    if (!value.isFinite || value < 0 || !scaled.isFinite) {
      throw StateError('Invalid nutrition in the declared serving');
    }
    return NutrientAmount.known(scaled);
  }

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
