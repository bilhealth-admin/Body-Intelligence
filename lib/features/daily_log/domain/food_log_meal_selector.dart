/// Canonical meal targets used by the Food Log entry surface.
///
/// Keeping this list independent from the diary's persisted rows means the
/// user can choose a destination before any food is selected, including for an
/// empty meal. The selected value is still the existing meal type used by the
/// diary repository (`breakfast`, `lunch`, `dinner`, or `snack`).
const foodLogMealTypes = <String>['breakfast', 'lunch', 'dinner', 'snack'];

String normalizeFoodLogMealType(String? value) {
  return foodLogMealTypes.contains(value) ? value! : foodLogMealTypes.first;
}

String foodLogMealTitle(String type) {
  return switch (type) {
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'dinner' => 'Dinner',
    'snack' => 'Snacks',
    _ => 'Breakfast',
  };
}
