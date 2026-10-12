import 'dart:async';
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
import '../services/display_name_sync.dart';
import '../services/profile_photo_validation.dart';
import 'package:flutter/foundation.dart' show compute;
export 'profile_avatar_state.dart';

export '../services/display_name_sync.dart' show DisplayNameSync;

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

final displayNameSyncProvider = Provider<DisplayNameSync>((ref) {
  final sync = DisplayNameSync(
    preferences: ref.watch(preferencesRepositoryProvider),
    currentOwnerId: () => AppEnvironment.supabaseRuntimeReady
        ? Supabase.instance.client.auth.currentUser?.id
        : null,
    readRemote: (owner) async {
      final client = Supabase.instance.client;
      if (client.auth.currentUser?.id != owner) return null;
      final row = await client
          .from('bil_public_profiles')
          .select('display_name')
          .eq('user_id', owner)
          .maybeSingle();
      return row?['display_name'] as String?;
    },
    writeRemote: (owner, name) async {
      final client = Supabase.instance.client;
      if (client.auth.currentUser?.id != owner) return false;
      // Do not create a discoverable Community profile as a side effect of
      // editing a private profile. A missing row keeps the edit pending.
      final row = await client
          .from('bil_public_profiles')
          .update({
            'display_name': name,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', owner)
          .select('display_name')
          .maybeSingle();
      return row?['display_name'] == name;
    },
  );
  ref.onDispose(sync.dispose);
  return sync;
});

final displayNameProvider = StreamProvider<String?>((ref) {
  final preferences = ref.watch(preferencesRepositoryProvider);
  final sync = ref.watch(displayNameSyncProvider);
  return preferences.watch('displayName').distinct().map((value) {
    if (!_preferencesMatchCurrentAuth(preferences)) {
      return null;
    }
    final localName = value?.trim();
    unawaited(sync.synchronize());
    return localName == null || localName.isEmpty ? null : localName;
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
  final preferences = ref.watch(preferencesRepositoryProvider);
  return preferences.watch('profilePhoto').asyncMap((encoded) async {
    if (!_preferencesMatchCurrentAuth(preferences)) return null;
    if (encoded == null || encoded.isEmpty) return null;
    final bytes = base64Decode(encoded);
    if (!await compute(isDecodableProfilePhoto, bytes)) {
      throw const FormatException('Corrupt persisted profile photo.');
    }
    return _preferencesMatchCurrentAuth(preferences) ? bytes : null;
  });
});

final profilePhotoMetadataProvider = StreamProvider<Map<String, String>>((ref) {
  return ref.watch(preferencesRepositoryProvider).watchSnapshot(const [
    'profilePhotoPublicUrl',
    'profilePhotoDeleted',
    'profilePhotoPending',
  ]);
});

/// Shared cross-device reference. Pending local edits win over delayed reads.
final profilePhotoPublicUrlProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final preferences = ref.watch(preferencesRepositoryProvider);
  ref.watch(profilePhotoMetadataProvider);
  if (await preferences.get('profilePhotoDeleted') == 'true') return null;
  final stored = (await preferences.get('profilePhotoPublicUrl'))?.trim();
  final hasStoredUrl = stored != null && stored.isNotEmpty;
  final initialPhoto = await preferences.get('profilePhoto');
  final initialPending = await preferences.get('profilePhotoPending');
  final initialDeleted = await preferences.get('profilePhotoDeleted');
  final expected = {
    'profilePhoto': initialPhoto,
    'profilePhotoPublicUrl': stored,
    'profilePhotoPending': initialPending,
    'profilePhotoDeleted': initialDeleted,
  };
  if (initialPending == 'true' || !AppEnvironment.supabaseRuntimeReady) {
    return hasStoredUrl ? stored : null;
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
    if (!ref.mounted ||
        client.auth.currentUser?.id != user.id ||
        await preferences.get('profilePhotoDeleted') == 'true') {
      return null;
    }
    final url = (row?['avatar_url'] as String?)?.trim();
    if (url == null || url.isEmpty) {
      if (hasStoredUrl) {
        await preferences.mutateIfUnchanged(
          expected: expected,
          set: {'profilePhotoDeleted': 'true'},
          remove: const ['profilePhoto', 'profilePhotoPublicUrl'],
        );
      }
      return null;
    }
    if (url != stored) {
      final updated = await preferences.mutateIfUnchanged(
        expected: expected,
        set: {'profilePhotoPublicUrl': url},
        remove: const ['profilePhoto'],
      );
      if (!updated) {
        return (await preferences.get('profilePhotoPublicUrl'))?.trim();
      }
    }
    return url;
  } on Object {
    return hasStoredUrl ? stored : null;
  }
});

bool _preferencesMatchCurrentAuth(PreferencesRepository preferences) {
  if (!AppEnvironment.supabaseRuntimeReady) return true;
  final owner = Supabase.instance.client.auth.currentUser?.id.trim();
  return owner != null && owner.isNotEmpty && preferences.localOwnerId == owner;
}
