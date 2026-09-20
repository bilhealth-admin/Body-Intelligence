import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/features/weight/domain/weight_goal_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolved weight goal progress', () {
    test('preserves a crossed loss goal and reports it reached', () {
      final progress = resolveWeightGoalProgress(
        currentWeightKg: 84,
        targetWeightKg: 85,
        profileBaselineWeightKg: 93,
        storedGoalType: 'lose',
        storedTargetWeightKg: 85,
      );

      expect(progress.direction, WeightGoalDirection.lose);
      expect(progress.reached, isTrue);
      expect(progress.remainingKg, 0);
    });

    test('uses a positive remaining amount for gain goals', () {
      final progress = resolveWeightGoalProgress(
        currentWeightKg: 87.4,
        targetWeightKg: 90,
        profileBaselineWeightKg: 87.4,
      );

      expect(progress.direction, WeightGoalDirection.gain);
      expect(progress.reached, isFalse);
      expect(progress.remainingKg, closeTo(2.6, 0.0001));
    });
  });

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
