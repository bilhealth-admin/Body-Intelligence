import '../domain/serving_measure.dart';
import '../domain/unified_food.dart';
import 'food_unit_engine.dart';
import 'nutrition_calculation_engine.dart';

class ServingNutritionResult {
  final double quantity;
  final String unit;
  final double grams;
  final NutritionPortion nutrition;

  const ServingNutritionResult({
    required this.quantity,
    required this.unit,
    required this.grams,
    required this.nutrition,
  });
}

class ServingIntelligenceEngine {
  final NutritionCalculationEngine _nutritionEngine;

  const ServingIntelligenceEngine({
    this._nutritionEngine = const NutritionCalculationEngine(),
  });

  ServingNutritionResult calculateMass({
    required UnifiedFood food,
    required double quantity,
    required String unit,
  }) {
    _requirePositiveFinite(quantity, 'quantity');
    final parsedUnit = FoodUnitEngine.tryParse(unit);
    if (parsedUnit == null) {
      throw ArgumentError.value(unit, 'unit', 'Unsupported mass unit');
    }
    final grams = FoodUnitEngine.toGrams(quantity, parsedUnit);
    return _calculate(food: food, quantity: quantity, unit: unit, grams: grams);
  }

  ServingNutritionResult calculateFoodServing({
    required UnifiedFood food,
    required double count,
  }) {
    return calculateDefinedServing(
      food: food,
      count: count,
      serving: ServingMeasure(
        id: 'food:${food.id}:default',
        label: food.serving.unit,
        amount: food.serving.amount,
        unit: food.serving.unit,
        grams: food.serving.grams,
      ),
    );
  }

  ServingNutritionResult calculateDefinedServing({
    required UnifiedFood food,
    required double count,
    required ServingMeasure serving,
  }) {
    _requirePositiveFinite(count, 'count');
    _requirePositiveFinite(serving.amount, 'serving.amount');
    _requirePositiveFinite(serving.grams, 'serving.grams');
    final grams = serving.grams * count;
    return _calculate(
      food: food,
      quantity: count,
      unit: serving.label,
      grams: grams,
    );
  }

  List<ServingMeasure> optionsFor(
    UnifiedFood food, {
    Iterable<ServingMeasure> additional = const <ServingMeasure>[],
  }) {
    final options = <ServingMeasure>[
      ServingMeasure(
        id: 'food:${food.id}:default',
        label: food.serving.unit,
        amount: food.serving.amount,
        unit: food.serving.unit,
        grams: food.serving.grams,
      ),
      ...additional,
    ];
    final seen = <String>{};
    final accepted = <ServingMeasure>[];
    for (final option in options) {
      if (option.id.trim().isEmpty ||
          !option.amount.isFinite ||
          option.amount <= 0 ||
          !option.grams.isFinite ||
          option.grams <= 0) {
        continue;
      }
      if (seen.add(option.id.trim())) accepted.add(option);
    }
    return List<ServingMeasure>.unmodifiable(accepted);
  }

  ServingNutritionResult _calculate({
    required UnifiedFood food,
    required double quantity,
    required String unit,
    required double grams,
  }) {
    final nutrition = _nutritionEngine.calculate(food: food, grams: grams);
    return ServingNutritionResult(
      quantity: quantity,
      unit: unit.trim(),
      grams: grams,
      nutrition: nutrition,
    );
  }

  void _requirePositiveFinite(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'Must be finite and greater than 0',
      );
    }
  }
}
