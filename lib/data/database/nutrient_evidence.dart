enum TrackedNutrient { fiber, sodium, potassium, calcium, magnesium, sugar }

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
  }) {
    var mask = 0;
    if (fiber != null) mask |= bit(TrackedNutrient.fiber);
    if (sodium != null) mask |= bit(TrackedNutrient.sodium);
    if (potassium != null) mask |= bit(TrackedNutrient.potassium);
    if (calcium != null) mask |= bit(TrackedNutrient.calcium);
    if (magnesium != null) mask |= bit(TrackedNutrient.magnesium);
    if (sugar != null) mask |= bit(TrackedNutrient.sugar);
    return mask;
  }
}
