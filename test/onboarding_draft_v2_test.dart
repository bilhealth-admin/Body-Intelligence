import 'package:body_intelligence_log/core/units/measurement_units.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
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

  test('V2 draft resumes every canonical field at the saved step', () async {
    final birthDate = DateTime(1992, 5, 17);
    final draft = OnboardingDraft(
      stepId: 'neck',
      preferredName: 'Nora',
      goals: const {OnboardingGoal.loseWeight, OnboardingGoal.sleepRecovery},
      activity: 'moderate',
      regularExercise: true,
      birthDate: birthDate,
      sex: 'female',
      countryRegion: 'Egypt',
      localeTag: 'ar',
      system: MeasurementSystem.imperial,
      heightCm: 171.25,
      currentWeightKg: 76.55,
      targetWeightKg: 70.1,
      weeklyPaceKg: .5,
      waistCm: 84.2,
      neckCm: 36.1,
      hipsCm: 96.4,
      healthPermission: OnboardingPermissionStatus.requested,
      notificationPermission: OnboardingPermissionStatus.denied,
      remoteAiConsent: OnboardingRemoteAiConsent.granted,
      aiFocuses: const {CoachContextFocus.nutrition, CoachContextFocus.habits},
      estimatesAcknowledged: true,
    );

    await repository.save(draft);
    final restored = await repository.load();

    expect(restored?.stepId, 'neck');
    expect(restored?.birthDate, birthDate);
    expect(restored?.goals, draft.goals);
    expect(restored?.waistCm, 84.2);
    expect(restored?.neckCm, 36.1);
    expect(restored?.hipsCm, 96.4);
    expect(restored?.system, MeasurementSystem.imperial);
    expect(restored?.healthPermission, OnboardingPermissionStatus.requested);
    expect(restored?.aiFocuses, draft.aiFocuses);
  });

  test('display unit changes never round-trip canonical values', () {
    const metric = OnboardingDraft(
      heightCm: 170.123456,
      currentWeightKg: 72.987654,
      waistCm: 83.456789,
    );
    final imperial = metric.copyWith(system: MeasurementSystem.imperial);
    final metricAgain = imperial.copyWith(system: MeasurementSystem.metric);

    expect(metricAgain.heightCm, 170.123456);
    expect(metricAgain.currentWeightKg, 72.987654);
    expect(metricAgain.waistCm, 83.456789);
  });

  test('legacy age is not converted into an invented birth date', () async {
    final preferences = PreferencesRepository(database);
    await preferences.set(
      OnboardingDraft.legacyPreferenceKey,
      '{"version":1,"age":"34","heightCm":170,"goalType":"lose"}',
    );
    final restored = await repository.load();
    expect(restored, isNotNull);
    expect(restored!.birthDate, isNull);
  });

  test('legacy draft cannot smuggle an unsupported activity value', () async {
    final preferences = PreferencesRepository(database);
    await preferences.set(
      OnboardingDraft.legacyPreferenceKey,
      '{"version":1,"activity":"desk_job","heightCm":170}',
    );

    final restored = await repository.load();

    expect(restored, isNotNull);
    expect(restored!.activity, isNull);
  });

  test('an explicit empty AI context selection survives restart', () async {
    const draft = OnboardingDraft(
      stepId: 'ai',
      remoteAiConsent: OnboardingRemoteAiConsent.declined,
      aiFocuses: <CoachContextFocus>{},
    );
    await repository.save(draft);

    final restored = await repository.load();
    expect(restored?.remoteAiConsent, OnboardingRemoteAiConsent.declined);
    expect(restored?.aiFocuses, isEmpty);
  });

  test('invalid draft is ignored and clear removes both versions', () async {
    final preferences = PreferencesRepository(database);
    await preferences.set(OnboardingDraft.preferenceKey, '{not json');
    expect(await repository.load(), isNull);

    await repository.save(const OnboardingDraft(stepId: 'goals'));
    await repository.clear();
    expect(await repository.load(), isNull);
  });
}
