import 'runtime_copy_primary.dart';
import 'runtime_copy_secondary.dart';
import 'runtime_copy_workouts.dart';
import 'runtime_copy_small_features.dart';
import 'runtime_copy_dashboard.dart';
import 'runtime_copy_extended.dart';
import 'runtime_copy_profile.dart';
import 'runtime_copy_release_closure.dart';
import 'runtime_copy_coach.dart';
import 'runtime_copy_core_pages.dart';
import 'runtime_copy_trial.dart';
import 'runtime_copy_cuisines.dart';
import 'runtime_copy_diets.dart';
import 'runtime_copy_profile_photo.dart';
import 'runtime_copy_legal_status.dart';
import 'runtime_copy_check_in.dart';
import 'runtime_copy_body_model.dart';
import 'runtime_copy_ai_access.dart';
import 'runtime_copy_accessibility_wellness.dart';
import 'runtime_copy_cloud_sync.dart';
import 'runtime_copy_release_polish.dart';
import 'runtime_copy_release_actions.dart';
import 'runtime_copy_food_actions.dart';
import 'runtime_copy_daily_log_actions.dart';
import 'runtime_copy_fitness_watch.dart';
import 'runtime_copy_connected_health.dart';

/// Reviewed runtime copy used by legacy call-sites that still pass an English
/// sentence instead of a typed key. Every entry is complete in the five
/// production languages; missing entries fail debug and release audits.
abstract final class RuntimeCopy {
  static const supported = <String>{
    'ar',
    'en',
    'fr',
    'es',
    'tr',
    ...ExtendedRuntimeCopy.supported,
  };

  static const values = <String, Map<String, String>>{
    ...RuntimeCopyPrimary.values,
    ...RuntimeCopySecondary.values,
    ...RuntimeCopyWorkouts.values,
    ...RuntimeCopySmallFeatures.values,
    ...RuntimeCopyDashboard.values,
    ...RuntimeCopyTrial.values,
    ...RuntimeCopyCuisines.values,
    ...DietRuntimeCopy.values,
    ...CorePagesRuntimeCopy.values,
  };

  static String? resolve(String english, String localeTag) {
    final normalized = localeTag.replaceAll('_', '-').toLowerCase();
    final connectedHealth = ConnectedHealthRuntimeCopy.resolve(
      english,
      localeTag,
    );
    if (connectedHealth != null) return connectedHealth;
    final releasePolish = ReleasePolishRuntimeCopy.resolve(english, localeTag);
    if (releasePolish != null) return releasePolish;
    final releaseAction = ReleaseActionRuntimeCopy.resolve(english, localeTag);
    if (releaseAction != null) return releaseAction;
    final foodAction = FoodActionRuntimeCopy.resolve(english, localeTag);
    if (foodAction != null) return foodAction;
    final dailyLogAction = DailyLogActionRuntimeCopy.resolve(
      english,
      localeTag,
    );
    if (dailyLogAction != null) return dailyLogAction;
    final fitnessWatch = FitnessWatchRuntimeCopy.resolve(english, localeTag);
    if (fitnessWatch != null) return fitnessWatch;
    final cloudSync = CloudSyncConsentCopy.resolve(english, localeTag);
    if (cloudSync != null) return cloudSync;
    final accessibilityWellness = AccessibilityWellnessRuntimeCopy.resolve(
      english,
      localeTag,
    );
    if (accessibilityWellness != null) return accessibilityWellness;
    final aiAccess = AiAccessRuntimeCopy.resolve(english, localeTag);
    if (aiAccess != null) return aiAccess;
    final bodyModel = BodyModelRuntimeCopy.resolve(english, localeTag);
    if (bodyModel != null) return bodyModel;
    final releaseClosure = ReleaseClosureRuntimeCopy.resolve(
      english,
      localeTag,
    );
    if (releaseClosure != null) return releaseClosure;
    final profile = ProfileRuntimeCopy.resolve(english, localeTag);
    if (profile != null) return profile;
    final checkIn = CheckInRuntimeCopy.resolve(english, localeTag);
    if (checkIn != null) return checkIn;
    for (final tag in LegalStatusRuntimeCopy.supported) {
      if (tag.toLowerCase() == normalized) {
        final reviewed = LegalStatusRuntimeCopy.values[english]?[tag];
        if (reviewed != null) return reviewed;
      }
    }
    for (final tag in ProfilePhotoRuntimeCopy.supported) {
      if (tag.toLowerCase() == normalized) {
        final reviewed = ProfilePhotoRuntimeCopy.values[english]?[tag];
        if (reviewed != null) return reviewed;
      }
    }
    for (final tag in ExtendedRuntimeCopy.supported) {
      if (tag.toLowerCase() == normalized) {
        return ExtendedRuntimeCopy.values[english]?[tag];
      }
    }
    final language = normalized.split('-').first;
    final base =
        values[english]?[language] ??
        CoachRuntimeCopy.values[english]?[language];
    if (base != null) return base;
    final matches = ExtendedRuntimeCopy.supported
        .where(
          (tag) =>
              tag.toLowerCase() == language ||
              tag.toLowerCase().startsWith('$language-'),
        )
        .toList(growable: false);
    if (matches.length == 1) {
      return ExtendedRuntimeCopy.values[english]?[matches.single];
    }
    return null;
  }

  static bool get balanced {
    const base = <String>{'ar', 'en', 'fr', 'es', 'tr'};
    return values.values.every(
          (translations) =>
              translations.keys.toSet().containsAll(base) &&
              base.containsAll(translations.keys),
        ) &&
        CoachRuntimeCopy.values.values.every(
          (translations) =>
              translations.keys.toSet().containsAll(base) &&
              base.containsAll(translations.keys),
        ) &&
        <String>{
          ...values.keys,
          ...CoachRuntimeCopy.values.keys,
        }.every(ExtendedRuntimeCopy.values.containsKey) &&
        ProfilePhotoRuntimeCopy.values.values.every(
          (translations) =>
              translations.keys.toSet().containsAll(
                ProfilePhotoRuntimeCopy.supported,
              ) &&
              ProfilePhotoRuntimeCopy.supported.containsAll(translations.keys),
        ) &&
        LegalStatusRuntimeCopy.values.values.every(
          (translations) =>
              translations.keys.toSet().containsAll(
                LegalStatusRuntimeCopy.supported,
              ) &&
              LegalStatusRuntimeCopy.supported.containsAll(translations.keys),
        ) &&
        CheckInRuntimeCopy.balanced &&
        BodyModelRuntimeCopy.balanced &&
        AiAccessRuntimeCopy.balanced &&
        AccessibilityWellnessRuntimeCopy.balanced &&
        CloudSyncConsentCopy.balanced &&
        ConnectedHealthRuntimeCopy.balanced &&
        ReleasePolishRuntimeCopy.balanced &&
        ReleaseActionRuntimeCopy.balanced &&
        FoodActionRuntimeCopy.balanced &&
        DailyLogActionRuntimeCopy.balanced &&
        FitnessWatchRuntimeCopy.balanced &&
        ReleaseClosureRuntimeCopy.balanced &&
        ProfileRuntimeCopy.balanced &&
        ExtendedRuntimeCopy.values.values.every(
          (translations) =>
              translations.keys.toSet().containsAll(
                ExtendedRuntimeCopy.supported,
              ) &&
              ExtendedRuntimeCopy.supported.containsAll(translations.keys),
        );
  }
}
