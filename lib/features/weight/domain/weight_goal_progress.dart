import '../../../core/units/measurement_units.dart';

enum WeightGoalDirection { lose, gain, maintain }

/// Resolves the durable direction of a weight goal.
///
/// Once a goal exists, crossing its target must not silently turn a loss goal
/// into a gain goal (or the inverse). The stored goal type therefore wins while
/// it still refers to the displayed target. Legacy profiles without a goal row
/// fall back to the profile baseline that originally established the target.
WeightGoalDirection resolveWeightGoalDirection({
  required double currentWeightKg,
  required double targetWeightKg,
  required double? profileBaselineWeightKg,
  String? storedGoalType,
  double? storedTargetWeightKg,
}) {
  final storedTargetMatches =
      storedTargetWeightKg != null &&
      (storedTargetWeightKg - targetWeightKg).abs() < 0.01;
  if (storedTargetMatches) {
    switch (storedGoalType) {
      case 'lose':
        return WeightGoalDirection.lose;
      case 'gain':
        return WeightGoalDirection.gain;
      case 'maintain':
        return WeightGoalDirection.maintain;
    }
  }

  final baseline = profileBaselineWeightKg ?? currentWeightKg;
  if (targetWeightKg < baseline) return WeightGoalDirection.lose;
  if (targetWeightKg > baseline) return WeightGoalDirection.gain;
  return WeightGoalDirection.maintain;
}

/// Signed difference from the target in canonical kilograms.
///
/// This is deliberately `current - target`, independent of whether the saved
/// plan is a loss or gain plan. A positive value means the current weight is
/// above the target, a negative value means it is below the target, and zero
/// means both values match. Keeping the raw sign avoids the old UI bug where a
/// crossed target was clamped to zero.
double signedWeightRemainingKg({
  required double currentWeightKg,
  required double targetWeightKg,
}) {
  final value = currentWeightKg - targetWeightKg;
  return value.abs() < 0.0000001 ? 0 : value;
}

String formatSignedWeightValue({
  required double kilograms,
  required MeasurementSystem system,
}) {
  final converted = UnitConverter.weightFromKg(kilograms, system);
  final rounded = double.parse(converted.toStringAsFixed(1));
  if (rounded > 0) return '+${rounded.toStringAsFixed(1)}';
  if (rounded < 0) return rounded.toStringAsFixed(1);
  return '0.0';
}

String goalTypeForUpdate({
  required double currentWeightKg,
  required double targetWeightKg,
  String? storedGoalType,
  double? storedTargetWeightKg,
}) => resolveWeightGoalDirection(
  currentWeightKg: currentWeightKg,
  targetWeightKg: targetWeightKg,
  profileBaselineWeightKg: currentWeightKg,
  storedGoalType: storedGoalType,
  storedTargetWeightKg: storedTargetWeightKg,
).name;
