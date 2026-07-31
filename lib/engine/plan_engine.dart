import 'body_profile.dart';
import 'bmr_engine.dart';
import 'daily_targets.dart';
import 'hydration_engine.dart';
import 'nutrition_engine.dart';
import 'tdee_engine.dart';

class PlanRecommendation {
  const PlanRecommendation({
    required this.bmr,
    required this.tdee,
    required this.targets,
    required this.assumptions,
  });
  final double bmr;
  final double tdee;
  final DailyTargets targets;
  final List<String> assumptions;
}

class PlanOverrides {
  const PlanOverrides({
    this.calories,
    this.protein,
    this.carbs,
    this.fats,
    this.fiber,
    this.water,
  });
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fats;
  final int? fiber;
  final int? water;
}

class PlanEngine {
  const PlanEngine._();

  static PlanRecommendation recommend(BodyProfile profile) {
    final bmr = BMREngine.calculate(profile);
    final tdee = TDEEEngine.calculate(
      bmr: bmr,
      activityLevel: profile.activityLevel,
    );
    final nutrition = NutritionEngine.calculate(profile: profile, tdee: tdee);
    final water = HydrationEngine.calculate(profile);
    return PlanRecommendation(
      bmr: bmr,
      tdee: tdee,
      targets: DailyTargets(
        calories: nutrition.calories,
        protein: nutrition.protein,
        carbs: nutrition.carbs,
        fats: nutrition.fats,
        potassium: nutrition.potassium,
        sodium: nutrition.sodium,
        fiber: nutrition.fiber,
        water: water,
      ),
      assumptions: [
        'Mifflin–St Jeor BMR using the saved age, sex, height, and current weight',
        'Activity factor: ${profile.activityLevel}',
        'Goal direction: ${profile.goalType}',
        'Logged scale weight cannot distinguish fat from muscle',
      ],
    );
  }

  static DailyTargets effective(
    DailyTargets recommended,
    PlanOverrides? overrides,
  ) => DailyTargets(
    calories: overrides?.calories ?? recommended.calories,
    protein: overrides?.protein ?? recommended.protein,
    carbs: overrides?.carbs ?? recommended.carbs,
    fats: overrides?.fats ?? recommended.fats,
    potassium: recommended.potassium,
    sodium: recommended.sodium,
    fiber: overrides?.fiber ?? recommended.fiber,
    water: overrides?.water ?? recommended.water,
  );
}
