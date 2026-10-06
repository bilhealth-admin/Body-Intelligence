part of 'coach_food_v2.dart';

enum CoachFoodSourceKind {
  reference('reference'),
  label('label'),
  userFixed('user_fixed'),
  calculatedRecipe('calculated_recipe'),
  estimated('estimated');

  const CoachFoodSourceKind(this.wireName);
  final String wireName;

  static CoachFoodSourceKind parse(Object? value) {
    for (final kind in values) {
      if (value == kind.wireName) return kind;
    }
    _foodReject('invalid_source_kind');
  }
}

/// An attributed confidence score, not a grant of reference/verified status.
/// Missing confidence remains null; source kind never manufactures a score.
final class CoachFoodConfidence {
  CoachFoodConfidence({required double score, required String basis})
    : score = _foodNumber(score, 'confidence.score', maximum: 1),
      basis = _foodText(basis, 'confidence.basis', 400);

  factory CoachFoodConfidence.fromJson(Object? raw) {
    final value = _foodObject(
      raw,
      const {'score', 'basis'},
      const {'score', 'basis'},
      'confidence',
    );
    return CoachFoodConfidence(
      score: _foodNumber(value['score'], 'confidence.score', maximum: 1),
      basis: _foodText(value['basis'], 'confidence.basis', 400),
    );
  }

  final double score;
  final String basis;

  Map<String, Object?> toJson() => {'score': score, 'basis': basis};
}

final class CoachFoodSourceEvidence {
  CoachFoodSourceEvidence({
    required this.kind,
    required String ref,
    required String revision,
    this.confidence,
    String? ownerKey,
  }) : ref = _foodText(ref, 'source.ref', 500),
       revision = _foodText(revision, 'source.revision', 100),
       ownerKey = ownerKey == null
           ? null
           : _foodText(ownerKey, 'source.ownerKey', 128) {
    if (kind == CoachFoodSourceKind.userFixed && this.ownerKey == null) {
      _foodReject('fixed_owner_required');
    }
  }

  factory CoachFoodSourceEvidence.fromJson(Object? raw) {
    final value = _foodObject(
      raw,
      const {'kind', 'ref', 'revision', 'confidence', 'ownerKey'},
      const {'kind', 'ref', 'revision'},
      'source',
    );
    return CoachFoodSourceEvidence(
      kind: CoachFoodSourceKind.parse(value['kind']),
      ref: _foodText(value['ref'], 'source.ref', 500),
      revision: _foodText(value['revision'], 'source.revision', 100),
      confidence: value['confidence'] == null
          ? null
          : CoachFoodConfidence.fromJson(value['confidence']),
      ownerKey: value['ownerKey'] == null
          ? null
          : _foodText(value['ownerKey'], 'source.ownerKey', 128),
    );
  }

  final CoachFoodSourceKind kind;
  final String ref;
  final String revision;
  final CoachFoodConfidence? confidence;
  final String? ownerKey;

  Map<String, Object?> toJson() => {
    'kind': kind.wireName,
    'ref': ref,
    'revision': revision,
    'confidence': confidence?.toJson(),
    if (ownerKey != null) 'ownerKey': ownerKey,
  };
}

/// Exactly the thirteen nutrients already represented by BIL's FoodNutrient.
/// Total carbohydrate includes fiber; source adapters must normalize any
/// available-carbohydrate convention before constructing this contract.
final class CoachFoodNutrients {
  CoachFoodNutrients(Map<FoodNutrient, double?> values)
    : values = Map<FoodNutrient, double?>.unmodifiable({
        for (final nutrient in FoodNutrient.values)
          nutrient: values[nutrient] == null
              ? null
              : _foodNumber(values[nutrient], 'nutrients.${nutrient.name}'),
      });

  factory CoachFoodNutrients.fromJson(Object? raw) {
    final value = _foodObject(
      raw,
      {for (final nutrient in FoodNutrient.values) nutrient.name},
      const {},
      'nutrients',
    );
    return CoachFoodNutrients({
      for (final nutrient in FoodNutrient.values)
        nutrient: value[nutrient.name] == null
            ? null
            : _foodNumber(value[nutrient.name], 'nutrients.${nutrient.name}'),
    });
  }

  static const units = <FoodNutrient, String>{
    FoodNutrient.calories: 'kcal',
    FoodNutrient.protein: 'g',
    FoodNutrient.carbohydrates: 'g',
    FoodNutrient.fat: 'g',
    FoodNutrient.fiber: 'g',
    FoodNutrient.sugar: 'g',
    FoodNutrient.sodium: 'mg',
    FoodNutrient.potassium: 'mg',
    FoodNutrient.calcium: 'mg',
    FoodNutrient.magnesium: 'mg',
    FoodNutrient.phosphorus: 'mg',
    FoodNutrient.iron: 'mg',
    FoodNutrient.vitaminC: 'mg',
  };

  final Map<FoodNutrient, double?> values;

  double? operator [](FoodNutrient nutrient) => values[nutrient];

  double? get netCarbohydrates {
    final carbs = this[FoodNutrient.carbohydrates];
    final fiber = this[FoodNutrient.fiber];
    if (carbs == null || fiber == null) return null;
    if (fiber > carbs) _foodReject('carbohydrate_basis_conflict');
    return carbs - fiber;
  }

  Map<String, Object?> toJson() => {
    for (final nutrient in FoodNutrient.values) nutrient.name: values[nutrient],
  };

  void _validateBasis(double basisGrams) {
    for (final nutrient in FoodNutrient.values) {
      final value = this[nutrient];
      if (value == null) continue;
      final maximumPer100 = nutrient == FoodNutrient.calories
          ? 1000.0
          : units[nutrient] == 'g'
          ? 100.0
          : 100000.0;
      _foodNumber(
        value,
        'nutrients.${nutrient.name}',
        maximum: maximumPer100 * basisGrams / 100,
      );
    }
    final carbs = this[FoodNutrient.carbohydrates];
    if (carbs != null) {
      for (final nutrient in [FoodNutrient.fiber, FoodNutrient.sugar]) {
        final value = this[nutrient];
        if (value != null && value > carbs) {
          _foodReject('carbohydrate_basis_conflict', nutrient.name);
        }
      }
    }
  }
}

/// A food's complete immutable basis. Quantity is deliberately separate.
/// A later catalog edit cannot change this object or its content digest.
final class CoachFoodSnapshot {
  CoachFoodSnapshot({
    required String identity,
    required String name,
    required String preparedState,
    required double basisGrams,
    required this.nutrients,
    required this.source,
  }) : identity = _foodText(identity, 'identity', 200),
       name = _foodText(name, 'name', 240),
       preparedState = _foodText(preparedState, 'preparedState', 120),
       basisGrams = _foodNumber(
         basisGrams,
         'basisGrams',
         minimum: .001,
         maximum: 100000,
       ) {
    nutrients._validateBasis(this.basisGrams);
  }

  factory CoachFoodSnapshot.fromJson(Object? raw) {
    const fields = {
      'identity',
      'name',
      'preparedState',
      'basisGrams',
      'nutrients',
      'source',
    };
    final value = _foodObject(raw, fields, fields, 'food');
    return CoachFoodSnapshot(
      identity: _foodText(value['identity'], 'identity', 200),
      name: _foodText(value['name'], 'name', 240),
      preparedState: _foodText(value['preparedState'], 'preparedState', 120),
      basisGrams: _foodNumber(
        value['basisGrams'],
        'basisGrams',
        minimum: .001,
        maximum: 100000,
      ),
      nutrients: CoachFoodNutrients.fromJson(value['nutrients']),
      source: CoachFoodSourceEvidence.fromJson(value['source']),
    );
  }

  final String identity;
  final String name;
  final String preparedState;
  final double basisGrams;
  final CoachFoodNutrients nutrients;
  final CoachFoodSourceEvidence source;

  String get digest => _foodDigest(toJson());

  Map<String, Object?> toJson() => {
    'identity': identity,
    'name': name,
    'preparedState': preparedState,
    'basisGrams': basisGrams,
    'nutrients': nutrients.toJson(),
    'source': source.toJson(),
  };
}
