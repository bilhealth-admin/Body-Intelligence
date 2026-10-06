part of 'coach_food_v2.dart';

final class CoachFoodPortion {
  CoachFoodPortion({
    required this.food,
    required this.quantity,
    this.identityConfidence,
  }) {
    final foodOwner = food.source.ownerKey;
    final quantityOwner = quantity.evidence.conversion?.source.ownerKey;
    if (foodOwner != null &&
        quantityOwner != null &&
        foodOwner != quantityOwner) {
      _foodReject('food_quantity_owner_mismatch');
    }
  }

  factory CoachFoodPortion.fromJson(Object? raw) {
    final value = _foodObject(
      raw,
      const {'food', 'grams', 'quantityEvidence', 'identityConfidence'},
      const {'food', 'grams', 'quantityEvidence'},
      'portion',
    );
    return CoachFoodPortion(
      food: CoachFoodSnapshot.fromJson(value['food']),
      quantity: CoachFoodQuantity.fromJson({
        'grams': value['grams'],
        'quantityEvidence': value['quantityEvidence'],
      }),
      identityConfidence: value['identityConfidence'] == null
          ? null
          : CoachFoodConfidence.fromJson(value['identityConfidence']),
    );
  }

  factory CoachFoodPortion.decodeFromStorage(String raw) {
    if (raw.length > 65536) _foodReject('snapshot_too_large');
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      _foodReject('invalid_snapshot_json');
    }
    const fields = {'schema', 'portion'};
    final value = _foodObject(decoded, fields, fields, 'storedSnapshot');
    if (value['schema'] != storageSchema) {
      _foodReject('unsupported_snapshot_schema');
    }
    return CoachFoodPortion.fromJson(value['portion']);
  }

  static const storageSchema = 'bil.food.portion.v1';

  final CoachFoodSnapshot food;
  final CoachFoodQuantity quantity;
  final CoachFoodConfidence? identityConfidence;

  CoachFoodNutrients get nutrients =>
      CoachFoodNutrition.scale(food, quantity.grams);

  String get digest => _foodDigest(toJson());

  String encodeForStorage() =>
      jsonEncode({'schema': storageSchema, 'portion': toJson()});

  Map<String, Object?> toJson() => {
    'food': food.toJson(),
    ...quantity.toJson(),
    'identityConfidence': identityConfidence?.toJson(),
  };
}

final class CoachNutrientTotal {
  const CoachNutrientTotal._({
    required this.knownSubtotal,
    required this.missingItems,
    required this.totalItems,
  });

  final double knownSubtotal;
  final int missingItems;
  final int totalItems;

  bool get complete => missingItems == 0;
  double? get value => complete ? knownSubtotal : null;
  int get knownItems => totalItems - missingItems;
  double get coverage => totalItems == 0 ? 0 : knownItems / totalItems;
}

final class CoachFoodTotals {
  CoachFoodTotals._(Map<FoodNutrient, CoachNutrientTotal> values)
    : values = Map.unmodifiable(values);

  final Map<FoodNutrient, CoachNutrientTotal> values;

  CoachNutrientTotal operator [](FoodNutrient nutrient) => values[nutrient]!;

  double? get netCarbohydrates {
    final carbs = this[FoodNutrient.carbohydrates].value;
    final fiber = this[FoodNutrient.fiber].value;
    if (carbs == null || fiber == null) return null;
    if (fiber > carbs) _foodReject('carbohydrate_basis_conflict');
    return carbs - fiber;
  }
}

/// A bounded reviewed batch; actual atomic storage remains the repository's job.
final class CoachFoodReview {
  CoachFoodReview(Iterable<CoachFoodPortion> items)
    : items = List<CoachFoodPortion>.unmodifiable(items) {
    if (this.items.isEmpty || this.items.length > 30) {
      _foodReject('invalid_batch_size');
    }
  }

  final List<CoachFoodPortion> items;
  CoachFoodTotals get totals => CoachFoodNutrition.total(items);

  void checkOwner(CoachFoodOwnerScope scope) {
    for (final item in items) {
      scope.checkEvidence(item.food.source);
      final conversion = item.quantity.evidence.conversion;
      if (conversion != null) scope.checkEvidence(conversion.source);
    }
    scope.check();
  }
}

abstract final class CoachFoodNutrition {
  static CoachFoodNutrients scale(CoachFoodSnapshot food, double grams) {
    final portion = _foodNumber(grams, 'grams', minimum: .001, maximum: 100000);
    return CoachFoodNutrients({
      for (final nutrient in FoodNutrient.values)
        nutrient: food.nutrients[nutrient] == null
            ? null
            : food.nutrients[nutrient]! * portion / food.basisGrams,
    });
  }

  /// Rebuilds from immutable food bases, never an earlier aggregate or a mutable
  /// catalog row. No rounding occurs until the eventual presentation boundary.
  static CoachFoodTotals total(Iterable<CoachFoodPortion> portions) {
    final vectors = portions
        .map((portion) => portion.nutrients)
        .toList(growable: false);
    return CoachFoodTotals._({
      for (final nutrient in FoodNutrient.values)
        nutrient: _totalNutrient(vectors, nutrient),
    });
  }

  static CoachNutrientTotal _totalNutrient(
    List<CoachFoodNutrients> vectors,
    FoodNutrient nutrient,
  ) {
    var subtotal = 0.0;
    var compensation = 0.0;
    var missing = 0;
    for (final vector in vectors) {
      final value = vector[nutrient];
      if (value == null) {
        missing++;
        continue;
      }
      final corrected = value - compensation;
      final next = subtotal + corrected;
      compensation = (next - subtotal) - corrected;
      subtotal = _foodNumber(next, 'total.${nutrient.name}');
    }
    return CoachNutrientTotal._(
      knownSubtotal: subtotal,
      missingItems: missing,
      totalItems: vectors.length,
    );
  }
}
