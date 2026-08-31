import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/body_measurement_repository.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/plan_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_preferences.dart';
import 'package:body_intelligence_log/features/dashboard/composition/dashboard_intelligence_input_adapter.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/dietary_preferences_repository.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_completion_service.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_goal_bindings.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_plan_calculator.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PreferencesRepository preferences;
  late OnboardingDraftRepository drafts;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
    drafts = OnboardingDraftRepository(preferences);
  });

  tearDown(() => database.close());

  OnboardingDraft draft() => OnboardingDraft(
    stepId: 'review',
    preferredName: 'Nora',
    goals: const {
      OnboardingGoal.loseWeight,
      OnboardingGoal.improveNutrition,
      OnboardingGoal.sleepRecovery,
    },
    activity: 'moderate',
    regularExercise: true,
    birthDate: DateTime(1990, 5, 17),
    sex: 'female',
    countryRegion: 'Egypt',
    localeTag: 'ar',
    heightCm: 170,
    currentWeightKg: 80,
    targetWeightKg: 70,
    weeklyPaceKg: .5,
    waistCm: 82,
    neckCm: 34,
    hipsCm: 98,
    remoteAiConsent: OnboardingRemoteAiConsent.declined,
    aiFocuses: const {CoachContextFocus.nutrition, CoachContextFocus.habits},
    estimatesAcknowledged: true,
  );

  OnboardingCompletionService service({
    Future<void> Function(OnboardingCommitPhase phase)? hook,
  }) => OnboardingCompletionService(
    database: database,
    profiles: UserProfileRepository(database),
    weights: WeightRepository(database),
    goals: GoalRepository(database),
    measurements: BodyMeasurementRepository(database),
    plans: PlanRepository(database),
    preferences: preferences,
    dietaryPreferences: DietaryPreferencesRepository(preferences),
    drafts: drafts,
    phaseHook: hook,
  );

  test('full finish stores one coherent snapshot and clears draft', () async {
    final value = draft();
    final now = DateTime(2026, 8, 30, 9);
    final plan = OnboardingPlanCalculator.calculate(value, now: now);
    await drafts.save(value);

    await service().commit(draft: value, now: now);

    final profile = await UserProfileRepository(database).getProfile();
    final weights = await WeightRepository(database).getAll();
    final goal = await GoalRepository(database).getActive();
    final measurement = await BodyMeasurementRepository(database).getLatest();
    final savedPlan = await PlanRepository(
      database,
    ).getForProfile(profile!.uuid);

    expect(profile.currentWeight, 80);
    expect(profile.targetWeight, 70);
    expect(weights.single.weight, 80);
    expect(goal?.type, 'lose');
    expect(goal?.targetDate, plan.targetDate);
    expect(measurement?.waistCm, 82);
    expect(measurement?.neckCm, 34);
    expect(measurement?.hipsCm, 98);
    expect(savedPlan?.recommendedCalories, plan.targets.calories);
    expect(await preferences.get('profileDateOfBirth'), contains('1990-05-17'));
    expect(await preferences.get('displayName'), 'Nora');
    expect(await preferences.get('countryRegion'), 'Egypt');
    expect(await preferences.get('units'), 'metric');
    expect(
      OnboardingGoalBindings.decode(
        await preferences.get(OnboardingGoalBindings.storageKey),
      ),
      value.goals,
    );
    expect(
      CoachContextPreferences.decode(
        await preferences.get(CoachContextPreferences.storageKey),
      ).focuses,
      value.aiFocuses,
    );
    final bodyTwinInput = const DashboardIntelligenceInputAdapter().adapt(
      now: now,
      profile: profile,
      weights: const [],
      todayMeals: const [],
      todayWater: const [],
      allMeals: const [],
      allWater: const [],
      dailyLogs: const [],
      todayContexts: const [],
      allContexts: const [],
      memories: const [],
      skippedWeightToday: false,
      planSetting: savedPlan,
      latestBodyMeasurement: measurement,
    );
    expect(bodyTwinInput.profile.waistCm, 82);
    expect(bodyTwinInput.profile.neckCm, 34);
    expect(bodyTwinInput.profile.hipsCm, 98);
    expect(await drafts.load(), isNull);
  });

  test(
    'failure after plan write rolls everything back and keeps draft',
    () async {
      final value = draft();
      final now = DateTime(2026, 8, 30, 9);
      await drafts.save(value);

      await expectLater(
        service(
          hook: (phase) async {
            if (phase == OnboardingCommitPhase.plan) {
              throw StateError('injected-mid-commit-failure');
            }
          },
        ).commit(draft: value, now: now),
        throwsStateError,
      );

      expect(await UserProfileRepository(database).getProfile(), isNull);
      expect(await WeightRepository(database).getAll(), isEmpty);
      expect(await GoalRepository(database).getActive(), isNull);
      expect(await BodyMeasurementRepository(database).getLatest(), isNull);
      expect(await preferences.get('onboardingCompletedVersion'), isNull);
      expect((await drafts.load())?.stepId, 'review');
    },
  );

  test(
    'failure after draft deletion rolls the deletion and all writes back',
    () async {
      final value = draft();
      final now = DateTime(2026, 8, 30, 9);
      await drafts.save(value);

      await expectLater(
        service(
          hook: (phase) async {
            if (phase == OnboardingCommitPhase.draftCleared) {
              throw StateError('injected-after-draft-delete');
            }
          },
        ).commit(draft: value, now: now),
        throwsStateError,
      );

      expect(await UserProfileRepository(database).getProfile(), isNull);
      expect(await WeightRepository(database).getAll(), isEmpty);
      expect(await GoalRepository(database).getActive(), isNull);
      expect(await BodyMeasurementRepository(database).getLatest(), isNull);
      expect(await preferences.get('onboardingCompletedVersion'), isNull);
      expect((await drafts.load())?.stepId, 'review');
    },
  );

  test('re-onboarding updates active goal instead of duplicating it', () async {
    final value = draft();
    final now = DateTime(2026, 8, 30, 9);
    await drafts.save(value);
    await service().commit(draft: value, now: now);

    final rerun = value.copyWith(
      stepId: 'review',
      goals: const {OnboardingGoal.maintainWeight},
      targetWeightKg: 80,
      weeklyPaceKg: 0,
    );
    await drafts.save(rerun);
    await service().commit(draft: rerun, now: now);

    final rows = await database.select(database.goals).get();
    expect(rows, hasLength(1));
    expect(rows.single.type, 'maintain');
  });

  test('male completion never persists a stale or forged hip value', () async {
    final value = draft().copyWith(sex: 'male', hipsCm: 98);
    final now = DateTime(2026, 8, 30, 9);
    await drafts.save(value);

    await service().commit(draft: value, now: now);

    final measurement = await BodyMeasurementRepository(database).getLatest();
    expect(measurement?.hipsCm, isNull);
  });

  test(
    'skipped measurements clear stale profile, Body Twin and AI inputs',
    () async {
      final profiles = UserProfileRepository(database);
      final bodyMeasurements = BodyMeasurementRepository(database);
      await profiles.save(
        gender: 'female',
        age: 36,
        height: 170,
        currentWeight: 80,
        targetWeight: 70,
        activityLevel: 'moderate',
        exercises: true,
        waist: 90,
        neck: 38,
      );
      await bodyMeasurements.saveForDay(
        date: DateTime(2026, 8, 29, 9),
        waistCm: 90,
        neckCm: 38,
        hipsCm: 105,
      );
      final value = draft().copyWith(waistCm: null, neckCm: null, hipsCm: null);
      final now = DateTime(2026, 8, 30, 9);
      await drafts.save(value);

      await service().commit(draft: value, now: now);

      final profile = await profiles.getProfile();
      final latest = await bodyMeasurements.getLatest();
      expect(profile?.waist, isNull);
      expect(profile?.neck, isNull);
      expect(latest?.waistCm, isNull);
      expect(latest?.neckCm, isNull);
      expect(latest?.hipsCm, isNull);
      expect(latest?.date, now);
    },
  );

  test(
    'finish fails closed until an explicit remote AI choice exists',
    () async {
      final value = draft().copyWith(
        remoteAiConsent: OnboardingRemoteAiConsent.unknown,
      );
      await drafts.save(value);

      await expectLater(
        service().commit(draft: value, now: DateTime(2026, 8, 30, 9)),
        throwsStateError,
      );

      expect(await UserProfileRepository(database).getProfile(), isNull);
      expect(
        (await drafts.load())?.remoteAiConsent,
        OnboardingRemoteAiConsent.unknown,
      );
    },
  );
}
