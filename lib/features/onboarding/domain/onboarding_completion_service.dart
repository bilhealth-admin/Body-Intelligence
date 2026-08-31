import 'dart:convert';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/body_measurement_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../intelligence_center/domain/coach_context_preferences.dart';
import '../../nutrition/repositories/dietary_preferences_repository.dart';
import '../models/onboarding_draft.dart';
import 'adult_eligibility.dart';
import 'onboarding_goal_bindings.dart';
import 'onboarding_plan_calculator.dart';

enum OnboardingCommitPhase {
  profile,
  weight,
  goal,
  measurements,
  plan,
  preferences,
  draftCleared,
}

/// Commits the complete local onboarding snapshot in one Drift transaction.
/// A thrown error rolls every local mutation back, including draft deletion.
final class OnboardingCompletionService {
  const OnboardingCompletionService({
    required this.database,
    required this.profiles,
    required this.weights,
    required this.goals,
    required this.measurements,
    required this.plans,
    required this.preferences,
    required this.dietaryPreferences,
    required this.drafts,
    this.phaseHook,
  });

  final AppDatabase database;
  final UserProfileRepository profiles;
  final WeightRepository weights;
  final GoalRepository goals;
  final BodyMeasurementRepository measurements;
  final PlanRepository plans;
  final PreferencesRepository preferences;
  final DietaryPreferencesRepository dietaryPreferences;
  final OnboardingDraftRepository drafts;
  final Future<void> Function(OnboardingCommitPhase phase)? phaseHook;

  Future<void> commit({required OnboardingDraft draft, DateTime? now}) async {
    if (draft.preferredName.trim().isEmpty) {
      throw StateError('preferred_name_required');
    }
    if (draft.remoteAiConsent == OnboardingRemoteAiConsent.unknown) {
      throw StateError('remote_ai_choice_required');
    }
    if (draft.remoteAiConsent == OnboardingRemoteAiConsent.granted &&
        draft.aiFocuses.isEmpty) {
      throw StateError('remote_ai_focus_required');
    }
    if (!draft.estimatesAcknowledged) {
      throw StateError('estimates_acknowledgement_required');
    }

    final committedAt = now ?? DateTime.now();
    // Re-derive from the same canonical source at commit time. Callers cannot
    // accidentally persist a summary calculated for older draft values.
    final plan = OnboardingPlanCalculator.calculate(draft, now: committedAt);
    final age = BilAdultEligibility.ageOn(draft.birthDate!, on: committedAt);
    final existingProfile = await profiles.getProfile();
    final existingMeasurement = await measurements.getLatest();
    final existingGoal = await goals.getActive();
    final dietary = await dietaryPreferences.read();

    // The draft is authoritative here: an explicit Skip stores null and must
    // not silently revive an older circumference in Profile, Body Twin, or AI
    // context. Existing unrelated chest/arm/thigh history remains intact.
    final waist = draft.waistCm;
    final neck = draft.neckCm;
    final hips = draft.sex == 'female' ? draft.hipsCm : null;

    await database.transaction(() async {
      await profiles.save(
        gender: draft.sex!,
        age: age,
        height: draft.heightCm!,
        currentWeight: draft.currentWeightKg!,
        targetWeight: draft.targetWeightKg!,
        activityLevel: draft.activity!,
        exercises: draft.regularExercise,
        medicalConditions: existingProfile?.medicalConditions,
        waist: waist,
        neck: neck,
        chest: existingProfile?.chest,
        arm: existingProfile?.arm,
        thigh: existingProfile?.thigh,
      );
      await phaseHook?.call(OnboardingCommitPhase.profile);

      await weights.addWeight(
        draft.currentWeightKg!,
        date: committedAt,
        measurementContext: 'unspecified',
      );
      await phaseHook?.call(OnboardingCommitPhase.weight);

      final profile = await profiles.getProfile();
      if (profile == null) throw StateError('profile_commit_failed');
      await goals.save(
        uuid: existingGoal?.uuid,
        profileUuid: profile.uuid,
        type: draft.primaryWeightGoal,
        targetWeight: draft.targetWeightKg!,
        targetDate: plan.targetDate,
      );
      await phaseHook?.call(OnboardingCommitPhase.goal);

      await measurements.saveForDay(
        date: committedAt,
        waistCm: waist,
        neckCm: neck,
        hipsCm: hips,
        chestCm: existingMeasurement?.chestCm,
        armCm: existingMeasurement?.armCm,
        thighCm: existingMeasurement?.thighCm,
        allowEmptySnapshot: true,
      );
      await phaseHook?.call(OnboardingCommitPhase.measurements);

      final existingPlan = await plans.getForProfile(profile.uuid);
      await plans.save(
        profileUuid: profile.uuid,
        recommended: plan.targets,
        calories: existingPlan?.overrideCalories,
        protein: existingPlan?.overrideProtein,
        carbs: existingPlan?.overrideCarbs,
        fats: existingPlan?.overrideFats,
        fiber: existingPlan?.overrideFiber,
        water: existingPlan?.overrideWater,
      );
      await phaseHook?.call(OnboardingCommitPhase.plan);

      final focusPreferences = CoachContextPreferences(
        focuses: Set.unmodifiable(draft.aiFocuses),
      );
      await preferences.setManyInCurrentTransaction({
        'displayName': draft.preferredName.trim(),
        'units': draft.system.name,
        'countryRegion': draft.countryRegion.trim(),
        'locale': draft.localeTag,
        'profileDateOfBirth': draft.birthDate!.toIso8601String(),
        'healthDisclaimerAccepted': 'true',
        'timezoneName': committedAt.timeZoneName,
        'timezoneOffsetMinutes': committedAt.timeZoneOffset.inMinutes
            .toString(),
        'firstValueHandoffPending': 'false',
        'forceOnboarding': 'false',
        'onboardingCompletedVersion': '2',
        OnboardingGoalBindings.storageKey: OnboardingGoalBindings.encode(
          draft.goals,
        ),
        CoachContextPreferences.storageKey: focusPreferences.encode(),
        'onboarding.remoteAiConsent': draft.remoteAiConsent.name,
        'onboarding.permission.health': draft.healthPermission.name,
        'onboarding.permission.notifications':
            draft.notificationPermission.name,
        'onboarding.plan.v1': jsonEncode({
          'version': 1,
          'calculatedAt': committedAt.toUtc().toIso8601String(),
          'weeklyPaceKg': plan.weeklyPaceKg,
          'targetDate': plan.targetDate?.toIso8601String(),
          'recommended': {
            'calories': plan.targets.calories,
            'protein': plan.targets.protein,
            'carbs': plan.targets.carbs,
            'fats': plan.targets.fats,
            'fiber': plan.targets.fiber,
            'water': plan.targets.water,
          },
          'assumptions': plan.assumptions,
        }),
      });
      await dietaryPreferences.saveInCurrentTransaction(dietary);
      await phaseHook?.call(OnboardingCommitPhase.preferences);

      await drafts.clearInCurrentTransaction();
      await phaseHook?.call(OnboardingCommitPhase.draftCleared);
    });
  }
}
