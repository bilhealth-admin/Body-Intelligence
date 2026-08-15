import '../../../engine/bmr_engine.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/tdee_engine.dart';

class CoachHealthTools {
  const CoachHealthTools();

  Map<String, Object?> calculate({
    required int age,
    required String gender,
    required double heightCm,
    required double currentWeightKg,
    required double targetWeightKg,
    required String activityLevel,
    required bool exercises,
    double? waistCm,
  }) {
    final profile = BodyProfile(
      age: age,
      gender: gender,
      height: heightCm,
      weight: currentWeightKg,
      targetWeight: targetWeightKg,
      activityLevel: activityLevel,
      exercises: exercises,
    );
    final bmr = BMREngine.calculate(profile);
    final tdee = TDEEEngine.calculate(bmr: bmr, activityLevel: activityLevel);
    final bmi = currentWeightKg / ((heightCm / 100) * (heightCm / 100));
    final waistToHeight = waistCm == null ? null : waistCm / heightCm;
    final goalDelta = targetWeightKg - currentWeightKg;
    return {
      'goalDirection': goalDelta < 0
          ? 'lose'
          : goalDelta > 0
          ? 'gain'
          : 'maintain',
      'kilogramsToGoal': double.parse(goalDelta.abs().toStringAsFixed(2)),
      'bmrKcal': bmr.round(),
      'tdeeKcal': tdee.round(),
      'bmiScreeningValue': double.parse(bmi.toStringAsFixed(1)),
      'waistToHeightRatio': waistToHeight == null
          ? null
          : double.parse(waistToHeight.toStringAsFixed(3)),
      'healthyWaistScreeningUpperCm': double.parse(
        (heightCm * .5).toStringAsFixed(1),
      ),
      'obesityRiskScreening': bmi >= 30
          ? 'elevated_bmi_screening_signal'
          : bmi >= 25
          ? 'increased_bmi_screening_signal'
          : 'no_elevated_bmi_screening_signal',
      'notice': 'Screening estimates only; not a diagnosis.',
    };
  }
}
