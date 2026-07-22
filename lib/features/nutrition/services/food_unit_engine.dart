enum FoodMassUnit { gram, kilogram, ounce, pound }

class FoodUnitEngine {
  const FoodUnitEngine._();

  static const double gramsPerOunce = 28.349523125;
  static const double gramsPerPound = 453.59237;

  static double toGrams(double value, FoodMassUnit unit) {
    _validate(value);
    return switch (unit) {
      FoodMassUnit.gram => value,
      FoodMassUnit.kilogram => value * 1000,
      FoodMassUnit.ounce => value * gramsPerOunce,
      FoodMassUnit.pound => value * gramsPerPound,
    };
  }

  static double fromGrams(double grams, FoodMassUnit unit) {
    _validate(grams);
    return switch (unit) {
      FoodMassUnit.gram => grams,
      FoodMassUnit.kilogram => grams / 1000,
      FoodMassUnit.ounce => grams / gramsPerOunce,
      FoodMassUnit.pound => grams / gramsPerPound,
    };
  }

  static FoodMassUnit? tryParse(String unit) {
    switch (unit.trim().toLowerCase()) {
      case 'g':
      case 'gram':
      case 'grams':
      case 'غ':
      case 'جرام':
      case 'غرام':
        return FoodMassUnit.gram;
      case 'kg':
      case 'kilogram':
      case 'kilograms':
      case 'كغ':
      case 'كيلو':
      case 'كيلوغرام':
        return FoodMassUnit.kilogram;
      case 'oz':
      case 'ounce':
      case 'ounces':
      case 'أونصة':
      case 'اونصة':
        return FoodMassUnit.ounce;
      case 'lb':
      case 'lbs':
      case 'pound':
      case 'pounds':
      case 'رطل':
        return FoodMassUnit.pound;
      default:
        return null;
    }
  }

  static void _validate(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'Must be finite and non-negative',
      );
    }
  }
}
