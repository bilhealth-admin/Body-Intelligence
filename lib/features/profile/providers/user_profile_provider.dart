import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/units/measurement_units.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
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

final nutritionGoalScheduleRepositoryProvider =
    Provider<NutritionGoalScheduleRepository>((ref) {
      return NutritionGoalScheduleRepository(
        ref.watch(preferencesRepositoryProvider),
      );
    });

final nutritionGoalScheduleProvider = StreamProvider<NutritionGoalSchedule>((
  ref,
) {
  return ref.watch(nutritionGoalScheduleRepositoryProvider).watch();
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

final firstValueHandoffProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(preferencesRepositoryProvider)
      .watch('firstValueHandoffPending')
      .map((value) => value == 'true');
});

final displayNameProvider = StreamProvider<String?>((ref) {
  return ref.watch(preferencesRepositoryProvider).watch('displayName').map((
    value,
  ) {
    final name = value?.trim();
    return name == null || name.isEmpty ? null : name;
  });
});

final activeNutritionPathwayProvider = StreamProvider<String?>((ref) {
  return ref
      .watch(preferencesRepositoryProvider)
      .watch('activeNutritionPathway')
      .map((value) => value?.trim().isEmpty == true ? null : value);
});

final forceOnboardingProvider = FutureProvider.autoDispose<bool>((ref) async {
  final value = await ref
      .watch(preferencesRepositoryProvider)
      .get('forceOnboarding');
  return value == 'true';
});

final userProfileProvider = StreamProvider<UserProfileData?>(
  (ref) {
    final repository = ref.watch(userProfileRepositoryProvider);
    return repository.watchProfile();
  },
  // Dashboard recovery is an explicit user action. Automatic retries leave
  // delayed timers alive after a failed local-store read and can race a later
  // manual retry or widget disposal.
  retry: (_, _) => null,
);

final accountGatewayReviewedProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final value = await ref
      .watch(preferencesRepositoryProvider)
      .get('accountGatewayReviewed');
  return value == 'true';
});

final profilePhotoProvider = StreamProvider<Uint8List?>((ref) {
  return ref.watch(preferencesRepositoryProvider).watch('profilePhoto').map((
    encoded,
  ) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  });
});
