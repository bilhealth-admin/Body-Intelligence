import 'body_profile.dart';
import 'daily_targets.dart';
import 'bmr_engine.dart';
import 'tdee_engine.dart';
import 'nutrition_engine.dart';
import 'hydration_engine.dart';
import 'recommendation_engine.dart';
import 'score.dart';
import 'score_engine.dart';

class BILResult {
  final double bmr;
  final double tdee;
  final DailyTargets targets;
  final DailyScore score;
  final List<String> recommendations;

  const BILResult({
    required this.bmr,
    required this.tdee,
    required this.targets,
    required this.score,
    required this.recommendations,
  });
}

class BILEngine {
  static BILResult calculate({
    required BodyProfile profile,
    required int eatenCalories,
    required int eatenProtein,
    required int drankWater,
  }) {
    final bmr = BMREngine.calculate(profile);

    final tdee = TDEEEngine.calculate(
      bmr: bmr,
      activityLevel: profile.activityLevel,
    );

    final targets = NutritionEngine.calculate(
      profile: profile,
      tdee: tdee,
    );

    final waterTarget = HydrationEngine.calculate(profile);

    final score = ScoreEngine.calculate(
      targetCalories: targets.calories,
      eatenCalories: eatenCalories,
      targetProtein: targets.protein,
      eatenProtein: eatenProtein,
      targetWater: waterTarget,
      drankWater: drankWater,
    );

    final recommendations = RecommendationEngine.recommendations(
      remainingProtein: targets.protein - eatenProtein,
      remainingPotassium: targets.potassium,
      remainingWater: waterTarget - drankWater,
    );

    return BILResult(
      bmr: bmr,
      tdee: tdee,
      targets: targets,
      score: score,
      recommendations: recommendations,
    );
  }
}