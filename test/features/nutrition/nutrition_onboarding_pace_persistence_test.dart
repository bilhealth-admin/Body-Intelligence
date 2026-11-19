import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/database_provider.dart';
import 'package:body_intelligence_log/data/repositories/body_measurement_repository.dart';
import 'package:body_intelligence_log/data/repositories/goal_repository.dart';
import 'package:body_intelligence_log/data/repositories/nutrition_goal_schedule_repository.dart';
import 'package:body_intelligence_log/data/repositories/plan_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_defaults_provider.dart';
import 'package:body_intelligence_log/features/nutrition/providers/nutrition_goal_snapshot_provider.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/dietary_preferences_repository.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_completion_service.dart';
import 'package:body_intelligence_log/features/onboarding/domain/onboarding_plan_calculator.dart';
import 'package:body_intelligence_log/features/onboarding/models/onboarding_draft.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:body_intelligence_log/features/weight/providers/weight_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// This fixture and the first test use only APIs present before the repair.
class PacePersistenceFixture {
  PacePersistenceFixture(this.db, this.preferences);

  final AppDatabase db;
  final PreferencesRepository preferences;
  late final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  static final now = DateTime(2026, 11, 18, 12);
  static final draft = OnboardingDraft(
    stepId: 'review',
    preferredName: 'Synthetic pace QA',
    goals: const {OnboardingGoal.loseWeight},
    activity: 'light',
    birthDate: DateTime(1990, 1, 1),
    sex: 'male',
    countryRegion: 'Jordan',
    heightCm: 170,
    currentWeightKg: 90,
    targetWeightKg: 86.25,
    weeklyPaceKg: .75,
    remoteAiConsent: OnboardingRemoteAiConsent.declined,
    estimatesAcknowledged: true,
  );

  static Future<PacePersistenceFixture> create(String owner) async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: owner,
    );
    final prefs = PreferencesRepository(db);
    await OnboardingCompletionService(
      database: db,
      profiles: UserProfileRepository(db),
      weights: WeightRepository(db),
      goals: GoalRepository(db),
      measurements: BodyMeasurementRepository(db),
      plans: PlanRepository(db),
      preferences: prefs,
      dietaryPreferences: DietaryPreferencesRepository(prefs),
      drafts: OnboardingDraftRepository(prefs),
    ).commit(draft: draft, now: now);
    return PacePersistenceFixture(db, prefs);
  }

  final _inputClosers = <void Function()>[];

  Future<void> ready() async {
    _inputClosers.addAll(await holdPaceInputs(container));
  }

  Future<Map<String, double>> defaultsWhere(
    bool Function(Map<String, double>) matches,
  ) => waitDefaults(container, matches);

  Future<void> close() async {
    for (final close in _inputClosers.reversed) {
      close();
    }
    container.dispose();
    await db.close();
  }
}

/// Riverpod3 pauses unobserved streams: future reads alone are not a listener.
Future<List<void Function()>> holdPaceInputs(
  ProviderContainer container,
) async {
  final close = <void Function()>[
    container.listen(userProfileProvider, (_, _) {}).close,
    container.listen(activeGoalProvider, (_, _) {}).close,
    container.listen(latestWeightProvider, (_, _) {}).close,
  ];
  try {
    final profile = await container
        .read(userProfileProvider.future)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError('profile stream did not emit'),
        );
    await container
        .read(activeGoalProvider.future)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError('goal stream did not emit'),
        );
    final plan = planSettingProvider(profile!.uuid);
    close.add(container.listen(plan, (_, _) {}).close);
    await container
        .read(plan.future)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError('plan stream did not emit'),
        );
    await container
        .read(latestWeightProvider.future)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError('weight stream did not emit'),
        );
    return close;
  } on Object {
    for (final cancel in close.reversed) {
      cancel();
    }
    rethrow;
  }
}

Future<Map<String, double>> waitDefaults(
  ProviderContainer container,
  bool Function(Map<String, double>) matches,
) {
  final done = Completer<Map<String, double>>();
  final subscription = container.listen(nutritionGoalDefaultsProvider, (
    previous,
    next,
  ) {
    if (!done.isCompleted && matches(next)) done.complete(next);
  }, fireImmediately: true);
  return done.future
      .timeout(const Duration(seconds: 5))
      .whenComplete(subscription.close);
}

Future<NutritionGoalSnapshot> waitSnapshot(
  ProviderContainer container,
  double calories,
) {
  final done = Completer<NutritionGoalSnapshot>();
  final subscription = container.listen(nutritionGoalSnapshotProvider, (
    previous,
    next,
  ) {
    final snapshot = next.value;
    if (!done.isCompleted &&
        snapshot?.goals['goal.calories']?.value == calories) {
      done.complete(snapshot!);
    }
  }, fireImmediately: true);
  return done.future
      .timeout(const Duration(seconds: 5))
      .whenComplete(subscription.close);
}

void main() {
  test(
    'saved onboarding pace survives the first real Home default read',
    () async {
      final f = await PacePersistenceFixture.create('pace-owner-a');
      addTearDown(f.close);
      final profile = (await UserProfileRepository(f.db).getProfile())!;
      final saved = (await PlanRepository(f.db).getForProfile(profile.uuid))!;
      final payload = jsonDecode(
        (await f.preferences.get('onboarding.plan.v1'))!,
      );
      expect(payload['weeklyPaceKg'], -.75);
      expect(saved.recommendedCalories, 1633);
      expect(saved.recommendedProtein, 121);
      expect(saved.recommendedCarbs, 166);
      expect(saved.recommendedFats, 54);
      await f.ready();
      // On the preimage this settles to1958, so this is a value RED, not a load RED.
      final goals = await f.defaultsWhere(
        (value) => value['goal.calories'] != null,
      );
      expect(goals['goal.calories'], 1633);
      expect(goals['goal.proteinGrams'], 121);
      expect(goals['goal.fatGrams'], 54);
      expect(goals['goal.carbsGrams']!.round(), 166);
      expect(goals['goal.carbsGrams'], 165.75);
      expect(
        goals['goal.carbsPercent']! +
            goals['goal.proteinPercent']! +
            goals['goal.fatPercent']!,
        closeTo(100, .000001),
      );
      final snapshot = await waitSnapshot(f.container, 1633);
      expect(snapshot.goals['goal.proteinGrams']!.value, 121);
      expect(snapshot.goals['goal.carbsGrams']!.value!.round(), 166);
      expect(snapshot.goals['goal.fatGrams']!.value, 54);
      // A recommendation read must not manufacture manual goal preferences.
      expect(await f.preferences.get('goal.calories'), isNull);
    },
  );

  test(
    'selected pace recalculates with current weight and profile activity',
    () async {
      final f = await PacePersistenceFixture.create('pace-evolution');
      addTearDown(f.close);
      await f.ready();
      await f.defaultsWhere((value) => value['goal.calories'] == 1633);
      await WeightRepository(f.db).addWeight(88, date: DateTime(2026, 11, 19));
      await f.defaultsWhere((value) => value['goal.calories'] == 1605);
      await UserProfileRepository(f.db).save(
        gender: 'male',
        age: 36,
        height: 170,
        currentWeight: 90,
        targetWeight: 86.25,
        activityLevel: 'moderate',
        exercises: false,
      );
      final updated = await f.defaultsWhere(
        (value) => value['goal.calories'] == 1915,
      );
      expect(updated['goal.proteinGrams'], 121);
      final goal = (await GoalRepository(f.db).getActive())!;
      await GoalRepository(f.db).save(
        uuid: goal.uuid,
        profileUuid: goal.profileUuid,
        type: 'gain',
        targetWeight: 92,
      );
      // Explicit opposite goal uses its current legacy +300, never the old-.75.
      await f.defaultsWhere((value) => value['goal.calories'] == 3040);
    },
  );

  test(
    'manual plan and goal overrides plus scheduled days keep priority',
    () async {
      final f = await PacePersistenceFixture.create('pace-overrides');
      addTearDown(f.close);
      await f.ready();
      final profile = (await UserProfileRepository(f.db).getProfile())!;
      final recommended = OnboardingPlanCalculator.calculate(
        PacePersistenceFixture.draft,
        now: PacePersistenceFixture.now,
      ).targets;
      await PlanRepository(f.db).save(
        profileUuid: profile.uuid,
        recommended: recommended,
        calories: 2200,
        protein: 140,
        fats: 70,
      );
      final defaults = await f.defaultsWhere(
        (value) => value['goal.calories'] == 2200,
      );
      expect(defaults['goal.proteinGrams'], 140);
      expect(defaults['goal.fatGrams'], 70);
      expect(defaults['goal.carbsGrams'], 252.5);
      await f.preferences.setMany({
        'goal.calories': '1800',
        'goal.carbsPercent': '45',
        'goal.proteinPercent': '25',
        'goal.fatPercent': '30',
      });
      final snapshot = await waitSnapshot(f.container, 1800);
      expect(snapshot.goals['goal.proteinGrams']!.value, 112.5);
      final scheduleRepo = NutritionGoalScheduleRepository(f.preferences);
      const scheduled = NutritionGoalTarget(
        calories: 2300,
        carbsPercent: 50,
        proteinPercent: 20,
        fatPercent: 30,
      );
      await scheduleRepo.saveDay(DateTime.wednesday, scheduled);
      final stored = await scheduleRepo.read();
      final manual = NutritionGoalTarget(
        calories: snapshot.goals['goal.calories']!.value!,
        carbsPercent: snapshot.goals['goal.carbsPercent']!.value!,
        proteinPercent: snapshot.goals['goal.proteinPercent']!.value!,
        fatPercent: snapshot.goals['goal.fatPercent']!.value!,
      );
      expect(
        resolveDailyNutritionGoal(
          schedule: stored,
          date: DateTime(2026, 11, 18),
          defaultGoal: manual,
        )!.calories,
        2300,
      );
      expect(
        resolveDailyNutritionGoal(
          schedule: stored,
          date: DateTime(2026, 11, 19),
          defaultGoal: manual,
        )!.calories,
        1800,
      );
    },
  );

  test(
    'known legacy absence keeps the existing live calorie fallback',
    () async {
      final f = await PacePersistenceFixture.create('pace-legacy');
      addTearDown(f.close);
      await f.preferences.remove('onboarding.plan.v1');
      await f.ready();
      final goals = await f.defaultsWhere(
        (value) => value['goal.calories'] != null,
      );
      expect(goals['goal.calories'], 1958);
    },
  );
}
