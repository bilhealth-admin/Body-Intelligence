import '../domain/unified_food.dart';

class GramEngine {
  const GramEngine._();

  static double factor({required double grams, required double basisGrams}) {
    _requirePositiveFinite(basisGrams, 'basisGrams');
    _requireNonNegativeFinite(grams, 'grams');
    return grams / basisGrams;
  }

  static double scaleValue({
    required double value,
    required double grams,
    required double basisGrams,
  }) {
    _requireNonNegativeFinite(value, 'value');
    return value * factor(grams: grams, basisGrams: basisGrams);
  }

  static Map<FoodNutrient, NutrientAmount> scaleNutrients({
    required Map<FoodNutrient, NutrientAmount> nutrients,
    required double grams,
    required double basisGrams,
  }) {
    final multiplier = factor(grams: grams, basisGrams: basisGrams);
    return nutrients.map((nutrient, amount) {
      if (!amount.isKnown) {
        return MapEntry(nutrient, const NutrientAmount.missing());
      }
      return MapEntry(
        nutrient,
        NutrientAmount.known(amount.value * multiplier),
      );
    });
  }

  static void _requirePositiveFinite(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'Must be finite and greater than 0',
      );
    }
  }

  static void _requireNonNegativeFinite(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, name, 'Must be finite and non-negative');
    }
  }
}
