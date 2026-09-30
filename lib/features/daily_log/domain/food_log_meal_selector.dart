/// Canonical meal targets used by the standalone Food Log entry surface.
///
/// This list is independent from persisted diary rows so a user can choose a
/// destination before selecting a food. The values remain the existing meal
/// types consumed by the meal repository.
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
