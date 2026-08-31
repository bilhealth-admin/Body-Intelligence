import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/environment/app_environment.dart';
import '../../../core/units/measurement_units.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../onboarding/models/onboarding_draft.dart';
import '../../nutrition/domain/dietary_preferences.dart';
import '../../nutrition/repositories/dietary_preferences_repository.dart';
import '../../nutrition_plans/data/diet_plan_repository.dart';

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

final dietaryPreferencesRepositoryProvider =
    Provider<DietaryPreferencesRepository>((ref) {
      return DietaryPreferencesRepository(
        ref.watch(preferencesRepositoryProvider),
      );
    });

final dietaryPreferencesProvider = StreamProvider<DietaryPreferences>((ref) {
  return ref.watch(dietaryPreferencesRepositoryProvider).watch();
});

final nutritionGoalScheduleRepositoryProvider =
    Provider<NutritionGoalScheduleRepository>((ref) {
      return NutritionGoalScheduleRepository(
        ref.watch(preferencesRepositoryProvider),
      );
    });

final dietPlanRepositoryProvider = Provider<DietPlanRepository>((ref) {
  return DietPlanRepository(
    preferences: ref.watch(preferencesRepositoryProvider),
    schedule: ref.watch(nutritionGoalScheduleRepositoryProvider),
  );
});

final dietPlanCommandProvider = Provider<DietPlanCommand>((ref) {
  return DietPlanCommand(
    repository: ref.watch(dietPlanRepositoryProvider),
    verifiedSubscription: () =>
        ref.read(verifiedSubscriptionStateProvider.future),
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

final displayNameProvider = StreamProvider<String?>((ref) async* {
  final preferences = ref.watch(preferencesRepositoryProvider);
  await for (final value in preferences.watch('displayName')) {
    if (!_preferencesMatchCurrentAuth(preferences)) {
      yield null;
      continue;
    }
    final localName = value?.trim();
    if (AppEnvironment.supabaseRuntimeReady) {
      try {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          final row = await client
              .from('bil_public_profiles')
              .select('display_name')
              .eq('user_id', user.id)
              .maybeSingle();
          final remoteName = row?['display_name']?.toString().trim();
          if (remoteName != null && remoteName.isNotEmpty) {
            if (remoteName != localName) {
              await preferences.set('displayName', remoteName);
            }
            yield remoteName;
            continue;
          }
        }
      } on Object {
        // Offline/cloud failures fall back to the last locally known identity.
      }
    }
    yield localName == null || localName.isEmpty ? null : localName;
  }
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
  final preferences = ref.watch(preferencesRepositoryProvider);
  return preferences.watch('profilePhoto').map((encoded) {
    if (!_preferencesMatchCurrentAuth(preferences)) return null;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
  });
});

/// Resolves the same cloud-backed photo used by Community on a second device.
/// Local bytes remain first priority; this URL is only the cross-device path.
final profilePhotoPublicUrlProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final preferences = ref.watch(preferencesRepositoryProvider);
  final stored = (await preferences.get('profilePhotoPublicUrl'))?.trim();
  if (!AppEnvironment.supabaseRuntimeReady) {
    return stored == null || stored.isEmpty ? null : stored;
  }
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null || preferences.localOwnerId != user.id) return null;
  try {
    final row = await client
        .from('bil_public_profiles')
        .select('avatar_url')
        .eq('user_id', user.id)
        .maybeSingle();
    final url = (row?['avatar_url'] as String?)?.trim();
    if (url == null || url.isEmpty) {
      return stored == null || stored.isEmpty ? null : stored;
    }
    await preferences.set('profilePhotoPublicUrl', url);
    return url;
  } on Object {
    return stored == null || stored.isEmpty ? null : stored;
  }
});

bool _preferencesMatchCurrentAuth(PreferencesRepository preferences) {
  if (!AppEnvironment.supabaseRuntimeReady) return true;
  final owner = Supabase.instance.client.auth.currentUser?.id.trim();
  return owner != null &&
      owner.isNotEmpty &&
      preferences.localOwnerId == owner;
}
