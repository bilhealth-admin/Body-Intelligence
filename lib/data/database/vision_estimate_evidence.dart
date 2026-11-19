import 'dart:convert';
import '../../features/nutrition/domain/gemini_vision_estimate.dart';
import '../../features/nutrition/domain/unified_food.dart' show FoodNutrient;
import 'app_database.dart';
import 'nutrient_evidence.dart';

/// Immutable, owner-bound model evidence. It is never a catalog verification.
class VisionFoodEvidence {
  VisionFoodEvidence({
    required this.identity,
    required this.ownerKey,
    required this.estimate,
  }) {
    if (identity.isEmpty ||
        identity.length > 240 ||
        !RegExp(r'^account_[0-9a-f]{24}$').hasMatch(ownerKey) ||
        estimate.basis == null ||
        estimate.nutrients.toJson().values.every((value) => value == null)) {
      throw const FormatException('Invalid owner-bound photo estimate.');
    }
  }
  static const schema = 'bil.vision.estimate.food.v1';
  static const source = 'Google Gemini photo estimate';
  static const category = 'vision_estimate_v2';
  final String identity, ownerKey;
  final GeminiVisionEstimate estimate;
  double get basisQuantity => estimate.basis!.quantity;
  String get basisUnit => estimate.basis!.unit;
  double? get basisGrams => basisUnit == 'g' ? basisQuantity : null;
  double? value(FoodNutrient nutrient) => estimate.nutrients[nutrient];
  double? get netCarbohydrates => estimate.nutrients.netCarbohydrates;
  int get mask => TrackedNutrient.values.fold(
    0,
    (mask, n) => value(nutrientFor(n)) == null
        ? mask
        : mask | NutrientEvidenceMask.bit(n),
  );

  Map<String, Object?> toJson() => {
    'schema': schema,
    'identity': identity,
    'ownerKey': ownerKey,
    'estimate': estimate.toJson(),
  };
  String encode() => jsonEncode(toJson());
  factory VisionFoodEvidence.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw.keys.any(
          (key) => !const {
            'schema',
            'identity',
            'ownerKey',
            'estimate',
          }.contains(key),
        ) ||
        raw['schema'] != schema ||
        raw['identity'] is! String ||
        raw['ownerKey'] is! String) {
      throw const FormatException('Invalid photo estimate evidence.');
    }
    return VisionFoodEvidence(
      identity: raw['identity'] as String,
      ownerKey: raw['ownerKey'] as String,
      estimate: GeminiVisionEstimate.fromJson(raw['estimate']),
    );
  }
  factory VisionFoodEvidence.decode(String raw) =>
      VisionFoodEvidence.fromJson(_decode(raw));

  bool matchesFood(Food row, {String? expectedOwner}) =>
      (expectedOwner == null || ownerKey == expectedOwner) &&
      row.uuid == identity &&
      row.name == estimate.name &&
      row.category == category &&
      row.source == source &&
      !row.verified &&
      !row.isCustom &&
      _near(row.servingSize, basisQuantity) &&
      row.servingUnit == basisUnit &&
      row.nutrientEvidenceMask == mask &&
      FoodNutrient.values
          .where((n) => n.index <= FoodNutrient.vitaminC.index)
          .every((n) => _near(_foodValue(row, n), value(n) ?? 0));

  static FoodNutrient nutrientFor(TrackedNutrient n) =>
      FoodNutrient.values.byName(n.name);
}

class VisionMealEvidence {
  VisionMealEvidence({required this.food, required this.quantity}) {
    if (!quantity.isFinite || quantity <= 0 || quantity > 100000) {
      throw const FormatException('Invalid reviewed photo quantity.');
    }
    for (final n in FoodNutrient.values) {
      value(n);
    }
    _scale(food.netCarbohydrates);
  }
  static const schema = 'bil.vision.estimate.meal.v1';
  final VisionFoodEvidence food;
  final double quantity;
  double get factor => quantity / food.basisQuantity;
  double? value(FoodNutrient n) => _scale(food.value(n));
  double? get netCarbohydrates => _scale(food.netCarbohydrates);
  double? _scale(double? value) {
    if (value == null) return null;
    final scaled = value * factor;
    if (!scaled.isFinite || scaled < 0 || scaled > 1e9) {
      throw const FormatException('Invalid scaled photo estimate.');
    }
    return scaled;
  }

  int get mask => TrackedNutrient.values.fold(
    0,
    (mask, n) => value(VisionFoodEvidence.nutrientFor(n)) == null
        ? mask
        : mask | NutrientEvidenceMask.bit(n),
  );
  String encode() => jsonEncode({
    'schema': schema,
    'food': food.toJson(),
    'quantity': quantity,
  });
  factory VisionMealEvidence.decode(String raw) {
    final row = _decode(raw);
    if (row is! Map<String, dynamic> ||
        row.keys.any(
          (key) => !const {'schema', 'food', 'quantity'}.contains(key),
        ) ||
        row['schema'] != schema ||
        row['quantity'] is! num) {
      throw const FormatException('Invalid meal photo estimate.');
    }
    return VisionMealEvidence(
      food: VisionFoodEvidence.fromJson(row['food']),
      quantity: (row['quantity'] as num).toDouble(),
    );
  }
  bool matchesMeal(MealItem row, {String? expectedOwner}) =>
      (expectedOwner == null || food.ownerKey == expectedOwner) &&
      row.foodSourceSnapshot == VisionFoodEvidence.source &&
      !row.foodVerifiedSnapshot &&
      _near(row.quantity, quantity) &&
      _near(row.servingSizeSnapshot, food.basisQuantity) &&
      row.servingUnitSnapshot == food.basisUnit &&
      row.nutrientEvidenceMask == mask &&
      TrackedNutrient.values.every(
        (n) => _near(
          _mealValue(row, n),
          value(VisionFoodEvidence.nutrientFor(n)) ?? 0,
        ),
      );
}

Object? _decode(String raw) {
  if (utf8.encode(raw).length > 65536) {
    throw const FormatException('Photo estimate evidence too large.');
  }
  return jsonDecode(raw);
}

bool _near(double a, double b) =>
    a.isFinite &&
    b.isFinite &&
    a >= 0 &&
    b >= 0 &&
    (a - b).abs() <= 1e-9 * (1 + b.abs());
double _foodValue(Food food, FoodNutrient n) => switch (n) {
  FoodNutrient.calories => food.calories,
  FoodNutrient.protein => food.protein,
  FoodNutrient.carbohydrates => food.carbs,
  FoodNutrient.fat => food.fats,
  FoodNutrient.fiber => food.fiber,
  FoodNutrient.sugar => food.sugar,
  FoodNutrient.sodium => food.sodium,
  FoodNutrient.potassium => food.potassium,
  FoodNutrient.calcium => food.calcium,
  FoodNutrient.magnesium => food.magnesium,
  FoodNutrient.phosphorus => food.phosphorus,
  FoodNutrient.iron => food.iron,
  FoodNutrient.vitaminC => food.vitaminC,
  _ => 0,
};
double _mealValue(MealItem row, TrackedNutrient n) => switch (n) {
  TrackedNutrient.calories => row.calories,
  TrackedNutrient.protein => row.protein,
  TrackedNutrient.carbohydrates => row.carbs,
  TrackedNutrient.fat => row.fats,
  TrackedNutrient.fiber => row.fiber,
  TrackedNutrient.sugar => row.sugar,
  TrackedNutrient.sodium => row.sodium,
  TrackedNutrient.potassium => row.potassium,
  TrackedNutrient.calcium => row.calcium,
  TrackedNutrient.magnesium => row.magnesium,
  TrackedNutrient.phosphorus => row.phosphorus,
};
