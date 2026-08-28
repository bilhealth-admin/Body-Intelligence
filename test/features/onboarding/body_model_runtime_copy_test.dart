import 'package:body_intelligence_log/app/localization/runtime_copy_body_model.dart';
import 'package:body_intelligence_log/features/onboarding/bil_flagship_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('body-model copy is complete for all 25 release locales', () {
    expect(BodyModelRuntimeCopy.supported, hasLength(25));
    expect(BodyModelRuntimeCopy.balanced, isTrue);
    for (final key in BodyModelRuntimeCopy.values.keys) {
      for (final locale in BodyModelRuntimeCopy.supported) {
        expect(
          BodyModelRuntimeCopy.resolve(key, locale),
          isNotEmpty,
          reason: '$locale:$key',
        );
      }
    }
  });

  test('imperial onboarding values convert to canonical engine units', () {
    final draft = BilOnboardingDraft()
      ..units = BilUnits.imperial
      ..weight = 198.416035962
      ..height = 68.8976377953
      ..waist = 35.4330708661
      ..neck = 14.9606299213
      ..hips = 39.3700787402;

    expect(draft.weightKg, closeTo(90, 0.0001));
    expect(draft.heightCm, closeTo(175, 0.0001));
    expect(draft.waistCm, closeTo(90, 0.0001));
    expect(draft.neckCm, closeTo(38, 0.0001));
    expect(draft.hipsCm, closeTo(100, 0.0001));
  });
}
