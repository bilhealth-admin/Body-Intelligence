import 'body_profile.dart';
import 'daily_targets.dart';

class FoodPortionTotals {
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  const FoodPortionTotals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });
}

class NutritionEngine {
  static DailyTargets calculate({
    required BodyProfile profile,
    required double tdee,
  }) {
    final adjustment = switch (profile.goalType) {
      'lose' => -500,
      'gain' => 300,
      _ => 0,
    };
    int calories = (tdee + adjustment).round();

    if (calories < 1200) {
      calories = 1200;
    }

    final proteinBase = profile.goalType == 'maintain'
        ? profile.weight
        : profile.targetWeight;
    final protein = (proteinBase * (profile.exercises ? 1.8 : 1.4)).round();

    final fats = (calories * 0.30 / 9).round();

    final carbs = ((calories - protein * 4 - fats * 9) / 4).round();

    final water = (profile.weight * 35).round() + (profile.exercises ? 750 : 0);

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

  static FoodPortionTotals calculateFoodPortion({
    required double quantity,
    required double servingSize,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
  }) {
    final factor = quantity / (servingSize <= 0 ? 1 : servingSize);

    return FoodPortionTotals(
      calories: calories * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fats: fats * factor,
    );
  }
}
