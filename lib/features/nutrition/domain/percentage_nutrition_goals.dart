final class PercentageNutritionGoals {
  const PercentageNutritionGoals._({
    required this.calories,
    required this.carbohydratesGrams,
    required this.proteinGrams,
    required this.fatGrams,
  });

  final double calories;
  final double carbohydratesGrams;
  final double proteinGrams;
  final double fatGrams;

  static PercentageNutritionGoals? resolve({
    required double calories,
    required double carbohydratesPercent,
    required double proteinPercent,
    required double fatPercent,
  }) {
    final values = [calories, carbohydratesPercent, proteinPercent, fatPercent];
    if (values.any((value) => !value.isFinite || value < 0) ||
        calories < 500 ||
        calories > 10000 ||
        (carbohydratesPercent + proteinPercent + fatPercent - 100).abs() >
            .001) {
      return null;
    }
    return PercentageNutritionGoals._(
      calories: calories,
      carbohydratesGrams: calories * carbohydratesPercent / 100 / 4,
      proteinGrams: calories * proteinPercent / 100 / 4,
      fatGrams: calories * fatPercent / 100 / 9,
    );
  }
}
