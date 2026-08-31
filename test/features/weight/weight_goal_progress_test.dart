import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/weight/domain/weight_goal_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('signed weight remaining', () {
    test('is current minus goal without clamping', () {
      expect(
        signedWeightRemainingKg(currentWeightKg: 90, targetWeightKg: 80),
        10,
      );
      expect(
        signedWeightRemainingKg(currentWeightKg: 75, targetWeightKg: 80),
        -5,
      );
    });

    test('equal current and target is a normalized zero', () {
      expect(
        signedWeightRemainingKg(currentWeightKg: 75, targetWeightKg: 75),
        0,
      );
    });

    test('stored goal direction remains authoritative after crossing', () {
      expect(
        resolveWeightGoalDirection(
          currentWeightKg: 79,
          targetWeightKg: 80,
          profileBaselineWeightKg: 79,
          storedGoalType: 'lose',
          storedTargetWeightKg: 80,
        ),
        WeightGoalDirection.lose,
      );
    });

    test('formats explicit signs in kg and converted lb', () {
      expect(
        formatSignedWeightValue(kilograms: 1, system: MeasurementSystem.metric),
        '+1.0',
      );
      expect(
        formatSignedWeightValue(
          kilograms: -1,
          system: MeasurementSystem.imperial,
        ),
        '-2.2',
      );
      expect(
        formatSignedWeightValue(
          kilograms: 0,
          system: MeasurementSystem.imperial,
        ),
        '0.0',
      );
    });
  });
}
