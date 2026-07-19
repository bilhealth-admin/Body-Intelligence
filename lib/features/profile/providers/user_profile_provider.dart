import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/units/measurement_units.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../onboarding/models/onboarding_draft.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return UserProfileRepository(database);
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(databaseProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository(ref.watch(databaseProvider));
});

final onboardingDraftRepositoryProvider = Provider<OnboardingDraftRepository>((
  ref,
) {
  return OnboardingDraftRepository(ref.watch(preferencesRepositoryProvider));
});

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(databaseProvider));
});

final activeGoalProvider = StreamProvider<Goal?>((ref) {
  return ref.watch(goalRepositoryProvider).watchActive();
});

final planSettingProvider = StreamProvider.family<PlanSetting?, String>((
  ref,
  uuid,
) {
  return ref.watch(planRepositoryProvider).watchForProfile(uuid);
});

final measurementSystemProvider = StreamProvider<MeasurementSystem>((ref) {
  return ref
      .watch(preferencesRepositoryProvider)
      .watch('units')
      .map(
        (value) => value == 'imperial'
            ? MeasurementSystem.imperial
            : MeasurementSystem.metric,
      );
});

final userProfileProvider = StreamProvider<UserProfileData?>((ref) {
  final repository = ref.watch(userProfileRepositoryProvider);
  return repository.watchProfile();
});
