import 'body_profile.dart';
import 'body_model_engine.dart';
import 'daily_targets.dart';
import '../features/nutrition/domain/dietary_preferences.dart';

class PlanRecommendation {
  const PlanRecommendation({
    required this.bmr,
    required this.tdee,
    required this.targets,
    required this.assumptions,
    required this.bodyModel,
  });
  final double bmr;
  final double tdee;
  final DailyTargets targets;
  final List<String> assumptions;
  final BodyModelResult bodyModel;
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

  static PlanRecommendation recommend(
    BodyProfile profile, {
    DietaryPreferences dietaryPreferences = const DietaryPreferences(),
  }) {
    final model = BodyModelEngine.calculate(profile);
    return PlanRecommendation(
      bmr: model.bmrKcal,
      tdee: model.tdeeKcal,
      targets: model.targets,
      bodyModel: model,
      assumptions: [
        'Mifflin-St Jeor BMR using the saved age, sex, height, and current weight',
        'Activity factor: ${profile.activityLevel}',
        'Goal direction: ${profile.goalType}',
        'Dietary approach: ${dietaryPreferences.approach}; food-selection constraints do not alter nutrient requirements',
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
