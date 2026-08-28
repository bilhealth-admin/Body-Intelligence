import 'body_profile.dart';
import 'daily_targets.dart';
import 'body_model_engine.dart';
import 'recommendation_engine.dart';
import 'score.dart';
import 'score_engine.dart';

class BILResult {
  final double bmr;
  final double tdee;
  final DailyTargets targets;
  final DailyScore score;
  final List<String> recommendations;
  final BodyModelResult bodyModel;

  const BILResult({
    required this.bmr,
    required this.tdee,
    required this.targets,
    required this.score,
    required this.recommendations,
    required this.bodyModel,
  });
}

class BILEngine {
  static BILResult calculate({
    required BodyProfile profile,
    required int eatenCalories,
    required int eatenProtein,
    required int drankWater,
  }) {
    final model = BodyModelEngine.calculate(profile);
    final targets = model.targets;
    final waterTarget = targets.water;

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
      bmr: model.bmrKcal,
      tdee: model.tdeeKcal,
      targets: targets,
      score: score,
      recommendations: recommendations,
      bodyModel: model,
    );
  }
}
