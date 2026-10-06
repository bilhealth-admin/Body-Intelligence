import '../../features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'app_database.dart';
import 'nutrient_evidence.dart';

enum MealFoodEvidenceState { legacy, valid, invalid }

/// Validates the complete immutable basis and its compatibility projection.
/// An invalid modern snapshot is unavailable evidence, never a legacy fallback.
final class MealFoodEvidence {
  MealFoodEvidence._(this.item, this.state, this.portion)
    : _nutrients = portion?.nutrients;

  factory MealFoodEvidence.read(MealItem item, {String? ownerKey}) {
    final raw = item.foodEvidenceJson;
    if (raw == null) {
      if (item.foodSourceSnapshot.startsWith('coach_food_v2:')) {
        return MealFoodEvidence._(item, MealFoodEvidenceState.invalid, null);
      }
      return MealFoodEvidence._(item, MealFoodEvidenceState.legacy, null);
    }
    try {
      final portion = CoachFoodPortion.decodeFromStorage(raw);
      final sources = [
        portion.food.source,
        if (portion.quantity.evidence.conversion case final conversion?)
          conversion.source,
      ];
      if (ownerKey != null &&
          sources.any(
            (source) => source.ownerKey != null && source.ownerKey != ownerKey,
          )) {
        return MealFoodEvidence._(item, MealFoodEvidenceState.invalid, null);
      }
      final projected = projection(portion);
      final matches =
          _near(item.quantity, portion.quantity.grams) &&
          _near(item.servingSizeSnapshot, portion.food.basisGrams) &&
          item.servingUnitSnapshot == 'g' &&
          !item.foodVerifiedSnapshot &&
          item.foodSourceSnapshot == sourceLabel(portion) &&
          item.nutrientEvidenceMask == mask(portion) &&
          TrackedNutrient.values.every(
            (nutrient) =>
                _near(_legacyValue(item, nutrient), projected[nutrient] ?? 0),
          );
      return MealFoodEvidence._(
        item,
        matches ? MealFoodEvidenceState.valid : MealFoodEvidenceState.invalid,
        matches ? portion : null,
      );
    } on CoachFoodContractError {
      return MealFoodEvidence._(item, MealFoodEvidenceState.invalid, null);
    }
  }

  final MealItem item;
  final MealFoodEvidenceState state;
  final CoachFoodPortion? portion;
  final CoachFoodNutrients? _nutrients;

  bool get isModern => state != MealFoodEvidenceState.legacy;
  bool get isValid => state != MealFoodEvidenceState.invalid;

  double? value(TrackedNutrient nutrient) {
    if (state == MealFoodEvidenceState.invalid) return null;
    final modern = portion;
    if (modern != null) return _nutrients![foodNutrient(nutrient)];
    final raw = _legacyValue(item, nutrient);
    return raw.isFinite &&
            raw >= 0 &&
            NutrientEvidenceMask.isKnown(
              mask: item.nutrientEvidenceMask,
              source: item.foodSourceSnapshot,
              nutrient: nutrient,
              value: raw,
            )
        ? raw
        : null;
  }

  double? fullValue(FoodNutrient nutrient) {
    if (state == MealFoodEvidenceState.invalid) return null;
    if (portion != null) return _nutrients![nutrient];
    for (final tracked in TrackedNutrient.values) {
      if (foodNutrient(tracked) == nutrient) return value(tracked);
    }
    // Legacy MealItems never captured iron or vitamin C. Today's Food is not
    // evidence for a historical item, even when its current value is nonzero.
    return null;
  }

  Map<TrackedNutrient, double?> get values => Map.unmodifiable({
    for (final nutrient in TrackedNutrient.values) nutrient: value(nutrient),
  });

  static String sourceLabel(CoachFoodPortion portion) =>
      'coach_food_v2:${portion.food.source.kind.wireName}';

  static int mask(CoachFoodPortion portion) => TrackedNutrient.values.fold(
    0,
    (result, nutrient) => portion.nutrients[foodNutrient(nutrient)] == null
        ? result
        : result | NutrientEvidenceMask.bit(nutrient),
  );

  static Map<TrackedNutrient, double?> projection(CoachFoodPortion portion) => {
    for (final nutrient in TrackedNutrient.values)
      nutrient: portion.nutrients[foodNutrient(nutrient)],
  };

  static FoodNutrient foodNutrient(TrackedNutrient nutrient) =>
      switch (nutrient) {
        TrackedNutrient.calories => FoodNutrient.calories,
        TrackedNutrient.protein => FoodNutrient.protein,
        TrackedNutrient.carbohydrates => FoodNutrient.carbohydrates,
        TrackedNutrient.fat => FoodNutrient.fat,
        TrackedNutrient.fiber => FoodNutrient.fiber,
        TrackedNutrient.sodium => FoodNutrient.sodium,
        TrackedNutrient.potassium => FoodNutrient.potassium,
        TrackedNutrient.calcium => FoodNutrient.calcium,
        TrackedNutrient.magnesium => FoodNutrient.magnesium,
        TrackedNutrient.sugar => FoodNutrient.sugar,
        TrackedNutrient.phosphorus => FoodNutrient.phosphorus,
      };

  static double _legacyValue(MealItem item, TrackedNutrient nutrient) =>
      switch (nutrient) {
        TrackedNutrient.calories => item.calories,
        TrackedNutrient.protein => item.protein,
        TrackedNutrient.carbohydrates => item.carbs,
        TrackedNutrient.fat => item.fats,
        TrackedNutrient.fiber => item.fiber,
        TrackedNutrient.sodium => item.sodium,
        TrackedNutrient.potassium => item.potassium,
        TrackedNutrient.calcium => item.calcium,
        TrackedNutrient.magnesium => item.magnesium,
        TrackedNutrient.sugar => item.sugar,
        TrackedNutrient.phosphorus => item.phosphorus,
      };

  static bool _near(double actual, double expected) =>
      actual.isFinite &&
      expected.isFinite &&
      (actual - expected).abs() <= 1e-9 * (1 + expected.abs());
}
