/// FDA label Daily Values, not individual RDA/AI, a laboratory normal range,
/// or a supplementation prescription. Total sugar/trans/mono/poly fats have
/// no assigned DV here; missing references must remain explicit, not zero.
abstract final class NutrientDailyReferences {
  static const sourceUrl =
      'https://www.fda.gov/food/nutrition-facts-label/daily-value-nutrition-and-supplement-facts-labels';
  static const values = <String, double>{
    'goal.sodium': 2300,
    'goal.potassium': 4700,
    'goal.fiber': 28,
    'goal.calciumMg': 1300,
    'goal.magnesium': 420,
    'goal.phosphorus': 1250,
    'goal.ironMg': 18,
    'goal.vitaminCMg': 90,
    'goal.vitaminAMcg': 900,
    'goal.saturatedFat': 20,
    'goal.cholesterol': 300,
  };
  static const upperBoundReferences = {
    'goal.sodium',
    'goal.saturatedFat',
    'goal.cholesterol',
  };
}
