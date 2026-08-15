enum TrackedNutrient {
  fiber,
  sodium,
  potassium,
  calcium,
  magnesium,
  sugar,
  phosphorus,
  calories,
  protein,
  carbohydrates,
  fat,
}

class NutrientEvidenceMask {
  const NutrientEvidenceMask._();

  static int bit(TrackedNutrient nutrient) => 1 << nutrient.index;

  static bool contains(int mask, TrackedNutrient nutrient) =>
      mask & bit(nutrient) != 0;

  static int fromValues({
    double? fiber,
    double? sodium,
    double? potassium,
    double? calcium,
    double? magnesium,
    double? sugar,
    double? phosphorus,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fat,
  }) {
    var mask = 0;
    if (fiber != null) mask |= bit(TrackedNutrient.fiber);
    if (sodium != null) mask |= bit(TrackedNutrient.sodium);
    if (potassium != null) mask |= bit(TrackedNutrient.potassium);
    if (calcium != null) mask |= bit(TrackedNutrient.calcium);
    if (magnesium != null) mask |= bit(TrackedNutrient.magnesium);
    if (sugar != null) mask |= bit(TrackedNutrient.sugar);
    if (phosphorus != null) mask |= bit(TrackedNutrient.phosphorus);
    if (calories != null) mask |= bit(TrackedNutrient.calories);
    if (protein != null) mask |= bit(TrackedNutrient.protein);
    if (carbohydrates != null) {
      mask |= bit(TrackedNutrient.carbohydrates);
    }
    if (fat != null) mask |= bit(TrackedNutrient.fat);
    return mask;
  }
}
