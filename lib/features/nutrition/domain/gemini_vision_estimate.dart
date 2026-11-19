import '../../intelligence_center/domain/food_v2/coach_food_v2.dart'
    show CoachFoodNutrients, FoodNutrient;

/// Gemini-provided nutrition, with no catalog or verified status attached.
class GeminiEstimateNutrients {
  GeminiEstimateNutrients(
    Map<FoodNutrient, double?> incoming, {
    required this.netCarbohydrates,
  }) : values = Map.unmodifiable({
         for (final n in FoodNutrient.values) n: incoming[n],
       }) {
    for (final value in [...values.values, netCarbohydrates]) {
      if (value != null && (!value.isFinite || value < 0 || value > 1e9)) {
        throw const FormatException('Invalid Gemini nutrient value.');
      }
    }
    final carbs = values[FoodNutrient.carbohydrates];
    final fiber = values[FoodNutrient.fiber];
    final sugar = values[FoodNutrient.sugar];
    if (carbs != null &&
        ((fiber != null && fiber > carbs + .1) ||
            (sugar != null && sugar > carbs + .1))) {
      throw const FormatException('Invalid Gemini carbohydrate basis.');
    }
    final fat = values[FoodNutrient.fat];
    if (carbs != null &&
        fiber != null &&
        sugar != null &&
        fiber + sugar > carbs + _rounding(carbs)) {
      throw const FormatException(
        'Fiber plus sugar exceeds total carbohydrate.',
      );
    }
    if (fat != null) {
      for (final nutrient in [
        FoodNutrient.saturatedFat,
        FoodNutrient.polyunsaturatedFat,
        FoodNutrient.monounsaturatedFat,
        FoodNutrient.transFat,
      ]) {
        final value = values[nutrient];
        if (value != null && value > fat + _rounding(fat)) {
          throw const FormatException('Fat subtype exceeds total fat.');
        }
      }
    }
    if (netCarbohydrates != null &&
        (carbs == null ||
            fiber == null ||
            (netCarbohydrates! - (carbs - fiber)).abs() > .2)) {
      throw const FormatException('Invalid Gemini net carbohydrate evidence.');
    }
  }
  static double _rounding(double reference) =>
      reference * .02 > .2 ? reference * .02 : .2;
  void _validateBasis(GeminiEstimateBasis? basis) {
    if (basis?.unit != 'g') return;
    final grams = basis!.quantity;
    if (netCarbohydrates != null && netCarbohydrates! > grams) {
      throw const FormatException('Net carbohydrate exceeds gram basis.');
    }
    final knownMass = [
      FoodNutrient.protein,
      FoodNutrient.carbohydrates,
      FoodNutrient.fat,
    ].fold(0.0, (sum, nutrient) => sum + (values[nutrient] ?? 0));
    if (knownMass > grams + _rounding(grams)) {
      throw const FormatException('Macro mass exceeds gram estimate basis.');
    }
    for (final n in FoodNutrient.values) {
      final value = values[n];
      final maximum = n == FoodNutrient.calories
          ? 1000
          : units[n] == 'g'
          ? 100
          : 100000;
      if (value != null && value > maximum * grams / 100) {
        throw const FormatException('Nutrient exceeds estimate gram basis.');
      }
    }
  }

  final Map<FoodNutrient, double?> values;
  final double? netCarbohydrates;
  static const units = CoachFoodNutrients.units;
  double? operator [](FoodNutrient nutrient) => values[nutrient];
  Map<String, Object?> toJson() => {
    for (final n in FoodNutrient.values) n.name: values[n],
    'netCarbohydrates': netCarbohydrates,
  };
  factory GeminiEstimateNutrients.fromJson(Object? raw) {
    final row = _estimateObject(raw, {
      for (final n in FoodNutrient.values) n.name,
      'netCarbohydrates',
    });
    return GeminiEstimateNutrients({
      for (final n in FoodNutrient.values) n: _estimateNumber(row[n.name]),
    }, netCarbohydrates: _estimateNumber(row['netCarbohydrates']));
  }
}

class GeminiEstimateBasis {
  GeminiEstimateBasis({required this.quantity, required this.unit}) {
    if (!quantity.isFinite ||
        quantity <= 0 ||
        quantity > 100000 ||
        !const {'g', 'ml', 'piece'}.contains(unit)) {
      throw const FormatException('Invalid Gemini estimate basis.');
    }
  }
  final double quantity;
  final String unit;
  Map<String, Object?> toJson() => {'quantity': quantity, 'unit': unit};
  factory GeminiEstimateBasis.fromJson(Object? raw) {
    final row = _estimateObject(raw, {'quantity', 'unit'});
    final quantity = _estimateNumber(row['quantity']);
    if (quantity == null) {
      throw const FormatException('Missing estimate basis.');
    }
    return GeminiEstimateBasis(
      quantity: quantity,
      unit: _estimateText(row['unit'], 24),
    );
  }
}

class GeminiVisionEstimate {
  GeminiVisionEstimate({
    required this.requestId,
    required this.index,
    required String name,
    required String modelRevision,
    required String promptRevision,
    required this.nutrients,
    required this.basis,
    required this.picturedAmount,
    required this.picturedUnit,
    String? uncertainty,
  }) : name = _estimateText(name, 160),
       modelRevision = _estimateText(modelRevision, 100),
       promptRevision = _estimateText(promptRevision, 100),
       uncertainty = uncertainty == null
           ? null
           : _estimateText(uncertainty, 300) {
    _estimateText(requestId, 128);
    nutrients._validateBasis(basis);
    if (index < 0 ||
        index >= 8 ||
        (picturedAmount != null &&
            (!picturedAmount!.isFinite ||
                picturedAmount! <= 0 ||
                picturedAmount! > 100000)) ||
        (picturedUnit != null &&
            !const {'g', 'ml', 'piece'}.contains(picturedUnit))) {
      throw const FormatException('Invalid Gemini photo estimate.');
    }
    if (basis == null &&
        nutrients.toJson().values.any((value) => value != null)) {
      throw const FormatException('Nutrition estimate has no source basis.');
    }
    if (basis != null && picturedUnit != null && basis!.unit != picturedUnit) {
      throw const FormatException(
        'Pictured portion and nutrition basis disagree.',
      );
    }
  }
  final String requestId, name, modelRevision, promptRevision;
  final int index;
  final GeminiEstimateNutrients nutrients;
  final GeminiEstimateBasis? basis;
  final double? picturedAmount;
  final String? picturedUnit, uncertainty;
  String get provider => 'gemini';

  Map<String, Object?> toJson() => {
    'requestId': requestId,
    'index': index,
    'name': name,
    'modelRevision': modelRevision,
    'promptRevision': promptRevision,
    'kind': 'gemini_photo_estimate',
    'provider': provider,
    'basis': basis?.toJson(),
    'nutrients': nutrients.toJson(),
    'picturedAmount': picturedAmount,
    'picturedUnit': picturedUnit,
    'uncertainty': uncertainty,
  };
  factory GeminiVisionEstimate.fromJson(Object? raw) {
    final row = _estimateObject(raw, {
      'requestId',
      'index',
      'name',
      'modelRevision',
      'promptRevision',
      'kind',
      'provider',
      'basis',
      'nutrients',
      'picturedAmount',
      'picturedUnit',
      'uncertainty',
    });
    if (row['kind'] != 'gemini_photo_estimate' ||
        row['provider'] != 'gemini' ||
        row['index'] is! int) {
      throw const FormatException('Invalid Gemini estimate provenance.');
    }
    return GeminiVisionEstimate(
      requestId: _estimateText(row['requestId'], 128),
      index: row['index'] as int,
      name: _estimateText(row['name'], 160),
      modelRevision: _estimateText(row['modelRevision'], 100),
      promptRevision: _estimateText(row['promptRevision'], 100),
      basis: row['basis'] == null
          ? null
          : GeminiEstimateBasis.fromJson(row['basis']),
      nutrients: GeminiEstimateNutrients.fromJson(row['nutrients']),
      picturedAmount: _estimateNumber(row['picturedAmount']),
      picturedUnit: row['picturedUnit'] == null
          ? null
          : _estimateText(row['picturedUnit'], 24),
      uncertainty: row['uncertainty'] == null
          ? null
          : _estimateText(row['uncertainty'], 300),
    );
  }
}

/// Created only after the explicit context-appropriate confirmation button.
/// It still requires the repository's owner/portion/atomic-commit checks.
class ReviewedGeminiVisionEstimate {
  ReviewedGeminiVisionEstimate({
    required this.estimate,
    required this.amount,
    required this.unit,
  }) {
    if (!amount.isFinite ||
        amount <= 0 ||
        amount > 100000 ||
        unit.trim().isEmpty ||
        unit.length > 24) {
      throw const FormatException('Invalid reviewed estimate portion.');
    }
  }
  final GeminiVisionEstimate estimate;
  final double amount;
  final String unit;
  Map<String, Object?> toJson() => {
    'estimate': estimate.toJson(),
    'amount': amount,
    'unit': unit,
  };
}

Map<String, dynamic> _estimateObject(Object? raw, Set<String> keys) {
  if (raw is! Map<String, dynamic> ||
      raw.keys.any((key) => !keys.contains(key))) {
    throw const FormatException('Invalid Gemini estimate object.');
  }
  return raw;
}

String _estimateText(Object? raw, int maximum) {
  if (raw is! String || raw.trim().isEmpty || raw.length > maximum) {
    throw const FormatException('Invalid Gemini estimate text.');
  }
  return raw.trim();
}

double? _estimateNumber(Object? raw) {
  if (raw == null) return null;
  if (raw is! num || !raw.isFinite || raw < 0 || raw > 1e9) {
    throw const FormatException('Invalid Gemini estimate number.');
  }
  return raw.toDouble();
}
