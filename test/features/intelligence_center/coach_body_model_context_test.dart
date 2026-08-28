import 'dart:io';

import 'package:body_intelligence_log/engine/body_model_engine.dart';
import 'package:body_intelligence_log/engine/body_profile.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_health_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Coach health output is the canonical body model output', () {
    const profile = BodyProfile(
      age: 30,
      gender: 'male',
      height: 180,
      weight: 80,
      targetWeight: 75,
      activityLevel: 'moderate',
      exercises: true,
      waistCm: 90,
      neckCm: 38,
    );
    final canonical = BodyModelEngine.calculate(profile);
    final output = const CoachHealthTools().calculate(
      age: profile.age,
      gender: profile.gender,
      heightCm: profile.height,
      currentWeightKg: profile.weight,
      targetWeightKg: profile.targetWeight,
      activityLevel: profile.activityLevel,
      exercises: profile.exercises,
      waistCm: profile.waistCm,
      neckCm: profile.neckCm,
    );

    expect(output['bodyModelVersion'], BodyModelEngine.version);
    expect(output['bmrKcal'], canonical.bmrKcal.round());
    expect(output['tdeeKcal'], canonical.tdeeKcal.round());
    expect(
      output['expectedBodyFatPercent'],
      double.parse(
        canonical.composition.bodyFatPercentage.value!.toStringAsFixed(1),
      ),
    );
    expect(
      output['expectedFatFreeMassKg'],
      double.parse(
        canonical.composition.fatFreeMassKg.value!.toStringAsFixed(1),
      ),
    );
    expect(output, isNot(contains('expectedLeanMassPercent')));
    expect(output, isNot(contains('expectedFatFreeMassPercent')));
    expect(output, isNot(contains('expectedLeanMassKg')));
    expect(output['bodyFatEstimateMethod'], 'circumferenceHodgdonBeckett');
    expect(output['bodyFatEstimateUncertainty'], 'lower');
    expect(output['notice'], contains('not a diagnosis'));
  });

  test('female hip measurement activates the circumference estimate', () {
    final output = const CoachHealthTools().calculate(
      age: 35,
      gender: 'female',
      heightCm: 165,
      currentWeightKg: 68,
      targetWeightKg: 62,
      activityLevel: 'light',
      exercises: true,
      waistCm: 78,
      neckCm: 34,
      hipCm: 100,
    );

    expect(output['expectedBodyFatPercent'], isA<double>());
    expect(output['expectedFatFreeMassKg'], isA<double>());
    expect(output, isNot(contains('expectedLeanMassPercent')));
    expect(output, isNot(contains('expectedFatFreeMassPercent')));
    expect(output['bodyFatEstimateMethod'], 'circumferenceHodgdonBeckett');
    expect(output['bodyFatEstimateUncertainty'], 'lower');
  });

  test('Coach context uses the latest saved circumferences everywhere', () {
    final source = File(
      'lib/features/intelligence_center/services/coach_context_provider.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('ref.read(bodyMeasurementRepositoryProvider).getLatest()'),
    );
    expect(
      source,
      contains('latestBodyMeasurement?.waistCm ?? profile?.waist'),
    );
    expect(source, contains('latestBodyMeasurement?.neckCm ?? profile?.neck'));
    expect(source, contains('latestBodyMeasurement?.hipsCm'));
    expect(RegExp(r'waistCm: latestWaistCm').allMatches(source), hasLength(2));
    expect(RegExp(r'neckCm: latestNeckCm').allMatches(source), hasLength(2));
    expect(RegExp(r'hipCm: latestHipCm').allMatches(source), hasLength(2));
  });
}
