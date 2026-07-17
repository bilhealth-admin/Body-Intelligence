import 'activity_factor.dart';

class TDEEEngine {
  static double calculate({
    required double bmr,
    required String activityLevel,
  }) {
    return bmr * activityFactor(activityLevel);
  }
}