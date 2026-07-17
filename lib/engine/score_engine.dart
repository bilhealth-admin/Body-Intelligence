import 'score.dart';

class ScoreEngine {
  static DailyScore calculate({
    required int targetCalories,
    required int eatenCalories,
    required int targetProtein,
    required int eatenProtein,
    required int targetWater,
    required int drankWater,
  }) {
    int score = 100;

    score -= ((targetCalories - eatenCalories).abs() / 50).round();

    score -= ((targetProtein - eatenProtein).abs() / 5).round();

    score -= ((targetWater - drankWater).abs() / 250).round();

    if (score < 0) score = 0;

    if (score > 100) score = 100;

    String message;

    if (score >= 90) {
      message = "Excellent";
    } else if (score >= 75) {
      message = "Very Good";
    } else if (score >= 60) {
      message = "Good";
    } else {
      message = "Needs Improvement";
    }

    return DailyScore(
      score: score,
      message: message,
    );
  }
}