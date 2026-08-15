import 'package:body_intelligence_log/features/nutrition/domain/percentage_nutrition_goals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts valid calorie percentages to gram targets using 4/4/9', () {
    final goals = PercentageNutritionGoals.resolve(
      calories: 2000,
      carbohydratesPercent: 45,
      proteinPercent: 30,
      fatPercent: 25,
    );

    expect(goals, isNotNull);
    expect(goals!.carbohydratesGrams, 225);
    expect(goals.proteinGrams, 150);
    expect(goals.fatGrams, closeTo(55.555, .001));
  });

  test('rejects corrupt, implausible, or non-100-percent storage', () {
    PercentageNutritionGoals? resolve(double calories, double carbs) =>
        PercentageNutritionGoals.resolve(
          calories: calories,
          carbohydratesPercent: carbs,
          proteinPercent: 30,
          fatPercent: 25,
        );

    expect(resolve(2000, 40), isNull);
    expect(resolve(499, 45), isNull);
    expect(resolve(10001, 45), isNull);
    expect(resolve(double.nan, 45), isNull);
    expect(resolve(2000, -5), isNull);
  });
}
