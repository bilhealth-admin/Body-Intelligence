import 'dart:convert';

import '../../features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'app_database.dart';
import 'nutrient_evidence.dart';

enum FoodBasisEvidenceState { legacy, valid, invalid }

/// Reads a modern immutable basis only when its complete database projection
/// agrees. Invalid modern data is unavailable, never a legacy macro fallback.
final class FoodBasisEvidence {
  const FoodBasisEvidence._(this.row, this.state, this.snapshot);

  factory FoodBasisEvidence.read(Food row, {String? ownerKey}) {
    FoodBasisEvidence invalid() =>
        FoodBasisEvidence._(row, FoodBasisEvidenceState.invalid, null);
    final raw = row.foodEvidenceJson;
    if (raw == null) {
      // Losing the envelope of an explicitly modern row cannot manufacture
      // the required-core semantics of a historical bundled food.
      if (row.source.startsWith('coach_food_v2:') ||
          row.category == 'coach_snapshot') {
        return invalid();
      }
      return FoodBasisEvidence._(row, FoodBasisEvidenceState.legacy, null);
    }
    try {
      if (utf8.encode(raw).length > 65536) return invalid();
      final envelope = jsonDecode(raw);
      if (envelope is! Map ||
          envelope.length != 2 ||
          envelope['schema'] != schema ||
          !envelope.containsKey('food')) {
        return invalid();
      }
      final food = CoachFoodSnapshot.fromJson(envelope['food']);
      if (ownerKey != null &&
          food.source.ownerKey != null &&
          food.source.ownerKey != ownerKey) {
        return invalid();
      }
      final matches =
          row.name == food.name &&
          _near(row.servingSize, food.basisGrams) &&
          row.servingUnit == 'g' &&
          !row.verified &&
          row.source == sourceLabel(food) &&
          row.nutrientEvidenceMask == mask(food) &&
          FoodNutrient.values.every(
            (nutrient) =>
                _near(_rowValue(row, nutrient), food.nutrients[nutrient] ?? 0),
          );
      return matches
          ? FoodBasisEvidence._(row, FoodBasisEvidenceState.valid, food)
          : invalid();
    } on FormatException {
      return invalid();
    } on CoachFoodContractError {
      return invalid();
    }
  }

  static const schema = 'bil.food.basis.v1';

  final Food row;
  final FoodBasisEvidenceState state;
  final CoachFoodSnapshot? snapshot;

  bool get isModern => state != FoodBasisEvidenceState.legacy;
  bool get isValid => state != FoodBasisEvidenceState.invalid;

  /// Only a valid immutable modern snapshot proves this gram basis. Legacy
  /// serving units require their existing explicit mass conversion instead.
  double? get basisGrams => snapshot?.basisGrams;

  double? value(FoodNutrient nutrient) {
    if (state == FoodBasisEvidenceState.invalid) return null;
    final food = snapshot;
    if (food != null) return food.nutrients[nutrient];
    final raw = _rowValue(row, nutrient);
    if (!raw.isFinite || raw < 0) return null;
    if (nutrient == FoodNutrient.iron || nutrient == FoodNutrient.vitaminC) {
      // Old Food rows defaulted these columns to zero without evidence bits.
      // Positive stored values remain usable; zero has no evidence of its own.
      return raw > 0 ? raw : null;
    }
    final known = NutrientEvidenceMask.contains(
      row.nutrientEvidenceMask,
      _tracked[nutrient]!,
    );
    if (!_core.contains(nutrient)) return known ? raw : null;
    // Preserve the adapter's historical required-core interpretation. Modern
    // rows already took the JSON path, including a legitimate all-zero mask.
    if (row.source == 'quick_add' || row.source.startsWith('BIL community')) {
      return known ? raw : null;
    }
    return row.source != 'bil-mobile-catalog' || known || raw != 0 ? raw : null;
  }

  Map<FoodNutrient, double?> get values => Map.unmodifiable({
    for (final nutrient in FoodNutrient.values) nutrient: value(nutrient),
  });

  static String encode(CoachFoodSnapshot food) =>
      jsonEncode({'schema': schema, 'food': food.toJson()});

  static String sourceLabel(CoachFoodSnapshot food) =>
      'coach_food_v2:${food.source.kind.wireName}';

  static int mask(CoachFoodSnapshot food) => _tracked.entries.fold(
    0,
    (result, entry) => food.nutrients[entry.key] == null
        ? result
        : result | NutrientEvidenceMask.bit(entry.value),
  );

  static Map<FoodNutrient, double?> projection(CoachFoodSnapshot food) =>
      food.nutrients.values;

  static const _core = {
    FoodNutrient.calories,
    FoodNutrient.protein,
    FoodNutrient.carbohydrates,
    FoodNutrient.fat,
  };
  static const _tracked = {
    FoodNutrient.calories: TrackedNutrient.calories,
    FoodNutrient.protein: TrackedNutrient.protein,
    FoodNutrient.carbohydrates: TrackedNutrient.carbohydrates,
    FoodNutrient.fat: TrackedNutrient.fat,
    FoodNutrient.fiber: TrackedNutrient.fiber,
    FoodNutrient.sugar: TrackedNutrient.sugar,
    FoodNutrient.sodium: TrackedNutrient.sodium,
    FoodNutrient.potassium: TrackedNutrient.potassium,
    FoodNutrient.calcium: TrackedNutrient.calcium,
    FoodNutrient.magnesium: TrackedNutrient.magnesium,
    FoodNutrient.phosphorus: TrackedNutrient.phosphorus,
  };

  static double _rowValue(Food row, FoodNutrient nutrient) =>
      switch (nutrient) {
        FoodNutrient.calories => row.calories,
        FoodNutrient.protein => row.protein,
        FoodNutrient.carbohydrates => row.carbs,
        FoodNutrient.fat => row.fats,
        FoodNutrient.fiber => row.fiber,
        FoodNutrient.sugar => row.sugar,
        FoodNutrient.sodium => row.sodium,
        FoodNutrient.potassium => row.potassium,
        FoodNutrient.calcium => row.calcium,
        FoodNutrient.magnesium => row.magnesium,
        FoodNutrient.phosphorus => row.phosphorus,
        FoodNutrient.iron => row.iron,
        FoodNutrient.vitaminC => row.vitaminC,
      };

  static bool _near(double actual, double expected) =>
      actual.isFinite &&
      actual >= 0 &&
      expected.isFinite &&
      (actual - expected).abs() <= 1e-9 * (1 + expected.abs());
}
