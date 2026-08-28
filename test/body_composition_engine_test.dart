import 'package:body_intelligence_log/engine/body_composition_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BodyCompositionEngine', () {
    test('male path preserves shipped circumference calculation', () {
      final result = BodyCompositionEngine.calculate(
        gender: 'male',
        age: 35,
        heightCm: 181,
        currentWeightKg: 93.9,
        neckCm: 40,
        waistCm: 100,
      );

      expect(result.bodyMassIndex.value, closeTo(28.6621, 0.0001));
      expect(result.bodyFatPercentage.value, closeTo(25.1039, 0.0001));
      expect(result.leanBodyMassKg.value, closeTo(70.3274, 0.0001));
      expect(
        result.bodyFatPercentage.method,
        BodyFatEstimateMethod.circumferenceHodgdonBeckett,
      );
      expect(result.waistToHeightRatio.value, closeTo(100 / 181, 0.0001));
    });

    test('female path preserves shipped BMI-age calculation', () {
      final result = BodyCompositionEngine.calculate(
        gender: 'female',
        age: 35,
        heightCm: 165,
        currentWeightKg: 68,
        neckCm: 34,
        waistCm: 82,
      );

      expect(result.bodyMassIndex.value, closeTo(24.9770, 0.0001));
      expect(result.bodyFatPercentage.value, closeTo(32.6225, 0.0001));
      expect(result.leanBodyMassKg.value, closeTo(45.8167, 0.0001));
      expect(
        result.bodyFatPercentage.method,
        BodyFatEstimateMethod.bmiAgeFallback,
      );
      expect(result.bodyFatPercentage.uncertainty, EstimateUncertainty.higher);
    });

    test(
      'female circumference path requires and uses hip with waist and neck',
      () {
        final result = BodyCompositionEngine.calculate(
          gender: 'female',
          age: 35,
          heightCm: 165,
          currentWeightKg: 68,
          neckCm: 34,
          waistCm: 82,
          hipCm: 100,
        );

        expect(result.bodyFatPercentage.value, closeTo(32.6728, 0.0001));
        expect(
          result.bodyFatPercentage.method,
          BodyFatEstimateMethod.circumferenceHodgdonBeckett,
        );
        expect(
          result.fatFreeMassKg.value,
          closeTo(68 * (1 - result.bodyFatPercentage.value! / 100), 0.0001),
        );
      },
    );

    test('missing optional neck uses higher-uncertainty male fallback', () {
      final result = BodyCompositionEngine.calculate(
        gender: 'male',
        age: 35,
        heightCm: 181,
        currentWeightKg: 93.9,
        neckCm: null,
        waistCm: 100,
      );

      expect(result.bodyFatPercentage.isAvailable, isTrue);
      expect(
        result.bodyFatPercentage.method,
        BodyFatEstimateMethod.bmiAgeFallback,
      );
      expect(result.bodyFatPercentage.uncertainty, EstimateUncertainty.higher);
      expect(result.leanBodyMassKg.isAvailable, isTrue);
    });

    test('missing optional waist uses higher-uncertainty male fallback', () {
      final result = BodyCompositionEngine.calculate(
        gender: 'male',
        age: 35,
        heightCm: 181,
        currentWeightKg: 93.9,
        neckCm: 40,
        waistCm: null,
      );

      expect(result.bodyFatPercentage.isAvailable, isTrue);
      expect(
        result.bodyFatPercentage.method,
        BodyFatEstimateMethod.bmiAgeFallback,
      );
      expect(result.bodyFatPercentage.uncertainty, EstimateUncertainty.higher);
      expect(result.leanBodyMassKg.isAvailable, isTrue);
    });

    test('invalid height is unavailable with a structured reason', () {
      final result = BodyCompositionEngine.calculate(
        gender: 'male',
        age: 35,
        heightCm: 0,
        currentWeightKg: 93.9,
        neckCm: 40,
        waistCm: 100,
      );

      expect(result.bodyMassIndex.issue, BodyCompositionIssue.invalidHeight);
      expect(
        result.bodyFatPercentage.issue,
        BodyCompositionIssue.invalidHeight,
      );
    });

    test('invalid weight is unavailable with a structured reason', () {
      final result = BodyCompositionEngine.calculate(
        gender: 'female',
        age: 35,
        heightCm: 165,
        currentWeightKg: -1,
        neckCm: 34,
        waistCm: 82,
      );

      expect(result.bodyMassIndex.issue, BodyCompositionIssue.invalidWeight);
      expect(
        result.bodyFatPercentage.issue,
        BodyCompositionIssue.invalidWeight,
      );
      expect(result.leanBodyMassKg.issue, BodyCompositionIssue.invalidWeight);
    });
  });
}
