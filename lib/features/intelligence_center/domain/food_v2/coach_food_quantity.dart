part of 'coach_food_v2.dart';

enum CoachFoodQuantityKind {
  measured('measured'),
  userDeclared('user_declared'),
  estimated('estimated');

  const CoachFoodQuantityKind(this.wireName);
  final String wireName;

  static CoachFoodQuantityKind parse(Object? value) {
    for (final kind in values) {
      if (value == kind.wireName) return kind;
    }
    _foodReject('invalid_quantity_kind');
  }
}

/// The original count/volume and the attributed factor remain reconstructible.
final class CoachFoodQuantityConversion {
  CoachFoodQuantityConversion({
    required double inputAmount,
    required this.inputUnit,
    required double gramsPerUnit,
    required this.source,
  }) : inputAmount = _foodNumber(
         inputAmount,
         'inputAmount',
         minimum: .001,
         maximum: 100000,
       ),
       gramsPerUnit = _foodNumber(
         gramsPerUnit,
         'gramsPerUnit',
         minimum: .001,
         maximum: 100000,
       ) {
    if (!const {'ml', 'item'}.contains(inputUnit)) {
      _foodReject('unsupported_conversion_unit');
    }
    if (inputUnit == 'ml' && this.gramsPerUnit > 30) {
      _foodReject('invalid_density');
    }
    _foodNumber(grams, 'convertedGrams', minimum: .001, maximum: 100000);
  }

  factory CoachFoodQuantityConversion.fromJson(Object? raw) {
    const fields = {'inputAmount', 'inputUnit', 'gramsPerUnit', 'source'};
    final value = _foodObject(raw, fields, fields, 'conversion');
    return CoachFoodQuantityConversion(
      inputAmount: _foodNumber(value['inputAmount'], 'inputAmount'),
      inputUnit: _foodText(value['inputUnit'], 'inputUnit', 10),
      gramsPerUnit: _foodNumber(value['gramsPerUnit'], 'gramsPerUnit'),
      source: CoachFoodSourceEvidence.fromJson(value['source']),
    );
  }

  final double inputAmount;
  final String inputUnit;
  final double gramsPerUnit;
  final CoachFoodSourceEvidence source;

  double get grams => inputAmount * gramsPerUnit;

  Map<String, Object?> toJson() => {
    'inputAmount': inputAmount,
    'inputUnit': inputUnit,
    'gramsPerUnit': gramsPerUnit,
    'source': source.toJson(),
  };
}

final class CoachFoodQuantityEvidence {
  CoachFoodQuantityEvidence({
    required this.kind,
    required String description,
    this.confidence,
    double? lowerGrams,
    double? upperGrams,
    this.conversion,
  }) : description = _foodText(description, 'quantity.description', 400),
       lowerGrams = lowerGrams == null
           ? null
           : _foodNumber(
               lowerGrams,
               'lowerGrams',
               minimum: .001,
               maximum: 100000,
             ),
       upperGrams = upperGrams == null
           ? null
           : _foodNumber(
               upperGrams,
               'upperGrams',
               minimum: .001,
               maximum: 100000,
             ) {
    if ((lowerGrams == null) != (upperGrams == null) ||
        (lowerGrams != null && lowerGrams > upperGrams!)) {
      _foodReject('invalid_quantity_interval');
    }
    if (conversion?.source.kind == CoachFoodSourceKind.estimated &&
        kind != CoachFoodQuantityKind.estimated) {
      _foodReject('estimated_conversion_requires_estimated_quantity');
    }
  }

  factory CoachFoodQuantityEvidence.fromJson(Object? raw) {
    final value = _foodObject(
      raw,
      const {
        'kind',
        'description',
        'confidence',
        'lowerGrams',
        'upperGrams',
        'conversion',
      },
      const {'kind', 'description'},
      'quantityEvidence',
    );
    return CoachFoodQuantityEvidence(
      kind: CoachFoodQuantityKind.parse(value['kind']),
      description: _foodText(value['description'], 'quantity.description', 400),
      confidence: value['confidence'] == null
          ? null
          : CoachFoodConfidence.fromJson(value['confidence']),
      lowerGrams: value['lowerGrams'] == null
          ? null
          : _foodNumber(value['lowerGrams'], 'lowerGrams'),
      upperGrams: value['upperGrams'] == null
          ? null
          : _foodNumber(value['upperGrams'], 'upperGrams'),
      conversion: value['conversion'] == null
          ? null
          : CoachFoodQuantityConversion.fromJson(value['conversion']),
    );
  }

  final CoachFoodQuantityKind kind;
  final String description;
  final CoachFoodConfidence? confidence;
  final double? lowerGrams;
  final double? upperGrams;
  final CoachFoodQuantityConversion? conversion;

  Map<String, Object?> toJson() => {
    'kind': kind.wireName,
    'description': description,
    'confidence': confidence?.toJson(),
    if (lowerGrams != null) 'lowerGrams': lowerGrams,
    if (upperGrams != null) 'upperGrams': upperGrams,
    if (conversion != null) 'conversion': conversion!.toJson(),
  };
}

final class CoachFoodQuantity {
  CoachFoodQuantity({required double grams, required this.evidence})
    : grams = _foodNumber(grams, 'grams', minimum: .001, maximum: 100000) {
    if ((evidence.lowerGrams != null && this.grams < evidence.lowerGrams!) ||
        (evidence.upperGrams != null && this.grams > evidence.upperGrams!)) {
      _foodReject('quantity_outside_interval');
    }
    final converted = evidence.conversion?.grams;
    if (converted != null && (converted - this.grams).abs() > 1e-9) {
      _foodReject('quantity_conversion_mismatch');
    }
  }

  factory CoachFoodQuantity.fromJson(Object? raw) {
    const fields = {'grams', 'quantityEvidence'};
    final value = _foodObject(raw, fields, fields, 'quantity');
    return CoachFoodQuantity(
      grams: _foodNumber(value['grams'], 'grams'),
      evidence: CoachFoodQuantityEvidence.fromJson(value['quantityEvidence']),
    );
  }

  final double grams;
  final CoachFoodQuantityEvidence evidence;

  Map<String, Object?> toJson() => {
    'grams': grams,
    'quantityEvidence': evidence.toJson(),
  };
}

/// An explicitly saved unit rule. There is no global egg, scoop or cup weight.
final class CoachFoodUnitRule {
  CoachFoodUnitRule({
    required String identity,
    required String preparedState,
    required this.inputUnit,
    required double gramsPerUnit,
    required this.source,
  }) : identity = _foodText(identity, 'rule.identity', 200),
       preparedState = _foodText(preparedState, 'rule.preparedState', 120),
       gramsPerUnit = _foodNumber(
         gramsPerUnit,
         'gramsPerUnit',
         minimum: .001,
         maximum: 100000,
       ) {
    if (!const {'ml', 'item'}.contains(inputUnit)) {
      _foodReject('unsupported_conversion_unit');
    }
    if (inputUnit == 'ml' && this.gramsPerUnit > 30) {
      _foodReject('invalid_density');
    }
  }

  final String identity;
  final String preparedState;
  final String inputUnit;
  final double gramsPerUnit;
  final CoachFoodSourceEvidence source;
}

abstract final class CoachFoodQuantities {
  /// Explicit grams take precedence. Caller-supplied measured vs declared
  /// evidence remains separate from a food source's confidence.
  static CoachFoodQuantity declaredGrams(
    double grams, {
    required String description,
    CoachFoodQuantityKind kind = CoachFoodQuantityKind.userDeclared,
    CoachFoodConfidence? confidence,
  }) => CoachFoodQuantity(
    grams: grams,
    evidence: CoachFoodQuantityEvidence(
      kind: kind,
      description: description,
      confidence: confidence,
    ),
  );

  /// Refuses ml without an identity/preparation-matched density rule.
  static CoachFoodQuantity fromUnit({
    required CoachFoodSnapshot food,
    required double amount,
    required String inputUnit,
    required CoachFoodUnitRule? rule,
    required CoachFoodOwnerScope scope,
    required String description,
    CoachFoodConfidence? confidence,
    double? lowerGrams,
    double? upperGrams,
    bool allowEstimate = false,
  }) {
    scope.check();
    if (rule == null) {
      _foodReject(
        inputUnit == 'ml' ? 'density_required' : 'unit_weight_required',
      );
    }
    if (rule.identity != food.identity ||
        rule.preparedState != food.preparedState ||
        rule.inputUnit != inputUnit) {
      _foodReject('unit_rule_identity_mismatch');
    }
    scope.checkEvidence(food.source);
    scope.checkEvidence(rule.source);
    if (rule.source.kind == CoachFoodSourceKind.estimated && !allowEstimate) {
      _foodReject('estimate_not_allowed');
    }
    final conversion = CoachFoodQuantityConversion(
      inputAmount: amount,
      inputUnit: inputUnit,
      gramsPerUnit: rule.gramsPerUnit,
      source: rule.source,
    );
    return CoachFoodQuantity(
      grams: conversion.grams,
      evidence: CoachFoodQuantityEvidence(
        kind: rule.source.kind == CoachFoodSourceKind.estimated
            ? CoachFoodQuantityKind.estimated
            : CoachFoodQuantityKind.userDeclared,
        description: description,
        confidence: confidence,
        lowerGrams: lowerGrams,
        upperGrams: upperGrams,
        conversion: conversion,
      ),
    );
  }
}
