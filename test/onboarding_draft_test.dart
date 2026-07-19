import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late OnboardingDraftRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = OnboardingDraftRepository(PreferencesRepository(database));
  });

  tearDown(() => database.close());

  test(
    'unfinished onboarding resumes all local fields at the saved step',
    () async {
      const draft = OnboardingDraft(
        step: 1,
        age: '34',
        heightCm: 171,
        currentWeightKg: 76.5,
        targetWeightKg: 70,
        waistCm: 84.2,
        neckCm: 36.1,
        region: 'Egypt',
        gender: 'female',
        activity: 'moderate',
        goalType: 'lose',
        system: MeasurementSystem.imperial,
        disclaimerAccepted: true,
      );

      await repository.save(draft);
      final restored = await repository.load();

      expect(restored?.step, 1);
      expect(restored?.age, '34');
      expect(restored?.waistCm, 84.2);
      expect(restored?.region, 'Egypt');
      expect(restored?.activity, 'moderate');
      expect(restored?.system, MeasurementSystem.imperial);
      expect(restored?.disclaimerAccepted, isTrue);
    },
  );

  test('invalid draft is ignored and completed setup can clear it', () async {
    final preferences = PreferencesRepository(database);
    await preferences.set(OnboardingDraft.preferenceKey, '{not valid json');
    expect(await repository.load(), isNull);

    await repository.save(const OnboardingDraft(step: 1, age: '29'));
    await repository.clear();
    expect(await repository.load(), isNull);
  });
}
