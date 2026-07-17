import 'body_profile.dart';
import 'daily_targets.dart';

class NutritionEngine {
  static DailyTargets calculate({
    required BodyProfile profile,
    required double tdee,
  }) {
    int calories = (tdee - 500).round();

    if (calories < 1200) {
      calories = 1200;
    }

    final protein =
    (profile.targetWeight * 2.2).round();

    final fats =
    (calories * 0.30 / 9).round();

    final carbs =
    ((calories -
        protein * 4 -
        fats * 9) /
        4)
        .round();

    final water =
    (profile.weight * 35).round();

    return DailyTargets(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      potassium: 4700,
      sodium: 2300,
      fiber: 35,
      water: water,
    );
  }
}