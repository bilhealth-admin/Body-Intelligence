import '../../../engine/body_model_engine.dart';
import '../../../engine/body_profile.dart';

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
    double? neckCm,
    double? hipCm,
  }) {
    final profile = BodyProfile(
      age: age,
      gender: gender,
      height: heightCm,
      weight: currentWeightKg,
      targetWeight: targetWeightKg,
      activityLevel: activityLevel,
      exercises: exercises,
      waistCm: waistCm,
      neckCm: neckCm,
      hipCm: hipCm,
    );
    final model = BodyModelEngine.calculate(profile);
    final composition = model.composition;
    final bodyFat = composition.bodyFatPercentage;
    double? rounded(double? value, int fractionDigits) => value == null
        ? null
        : double.parse(value.toStringAsFixed(fractionDigits));
    final goalDelta = targetWeightKg - currentWeightKg;
    return {
      'bodyModelVersion': model.version,
      'goalDirection': goalDelta < 0
          ? 'lose'
          : goalDelta > 0
          ? 'gain'
          : 'maintain',
      'kilogramsToGoal': double.parse(goalDelta.abs().toStringAsFixed(2)),
      'bmrKcal': model.bmrKcal.round(),
      'tdeeKcal': model.tdeeKcal.round(),
      'bmiScreeningValue': rounded(composition.bodyMassIndex.value, 1),
      'waistToHeightRatio': rounded(composition.waistToHeightRatio.value, 3),
      'expectedBodyFatPercent': rounded(bodyFat.value, 1),
      'expectedFatFreeMassKg': rounded(composition.fatFreeMassKg.value, 1),
      'bodyFatEstimateMethod': bodyFat.method?.name,
      'bodyFatEstimateUncertainty': bodyFat.uncertainty.name,
      'bodyFatEstimateIssue': bodyFat.issue?.name,
      'healthyWaistScreeningUpperCm': double.parse(
        (heightCm * .5).toStringAsFixed(1),
      ),
      'obesityRiskScreening': composition.bodyMassIndex.value! >= 30
          ? 'elevated_bmi_screening_signal'
          : composition.bodyMassIndex.value! >= 25
          ? 'increased_bmi_screening_signal'
          : 'no_elevated_bmi_screening_signal',
      'notice': 'Screening estimates only; not a diagnosis.',
    };
  }
}
