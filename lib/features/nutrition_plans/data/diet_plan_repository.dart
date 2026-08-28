import 'dart:convert';

import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../commerce/domain/subscription_state.dart';
import '../domain/diet_macro_plan.dart';
import '../domain/nutrition_pathway.dart';
import '../domain/nutrition_pathway_access_policy.dart';
import '../domain/nutrition_pathway_catalog.dart';

typedef VerifiedSubscriptionLoader = Future<SubscriptionState> Function();

enum NutritionPathwayActivationFailure {
  unknownPathway,
  premiumRequired,
  clinicianReviewRequired,
  medicalSupervisionRequired,
  invalidAuthorization,
}

final class NutritionPathwayActivationException implements Exception {
  const NutritionPathwayActivationException(this.failure);

  final NutritionPathwayActivationFailure failure;

  @override
  String toString() => 'NutritionPathwayActivationException($failure)';
}

/// An unforgeable capability created only after [DietPlanCommand] validates
/// the exact pathway, current server entitlement, and safety boundary.
final class NutritionPathwayActivationAuthorization {
  const NutritionPathwayActivationAuthorization._(this.pathwayId);

  final String pathwayId;
}

/// The only application command allowed to activate a nutrition pathway.
///
/// Presentation gates improve UX, but this command is the mutation boundary:
/// a deep link, stale widget, or direct UI callback still cannot bypass the
/// server-verified Premium grant or the PSMF medical lock.
final class DietPlanCommand {
  const DietPlanCommand({
    required this.repository,
    required this.verifiedSubscription,
  });

  final DietPlanRepository repository;
  final VerifiedSubscriptionLoader verifiedSubscription;

  Future<void> activate(
    DietDraft draft, {
    bool clinicianReviewConfirmed = false,
  }) async {
    final pathway = nutritionPathwayForExactId(draft.pathwayId);
    if (pathway == null) {
      throw const NutritionPathwayActivationException(
        NutritionPathwayActivationFailure.unknownPathway,
      );
    }

    SubscriptionState? subscription;
    if (pathway.access == NutritionPathwayAccess.premium) {
      try {
        subscription = await verifiedSubscription();
      } on Object {
        throw const NutritionPathwayActivationException(
          NutritionPathwayActivationFailure.premiumRequired,
        );
      }
    }
    if (!nutritionPathwayAccessGranted(pathway, subscription)) {
      throw const NutritionPathwayActivationException(
        NutritionPathwayActivationFailure.premiumRequired,
      );
    }
    if (pathway.safety == NutritionPathwaySafety.medicalSupervision) {
      throw const NutritionPathwayActivationException(
        NutritionPathwayActivationFailure.medicalSupervisionRequired,
      );
    }
    if (pathway.safety == NutritionPathwaySafety.clinicianReview &&
        !clinicianReviewConfirmed) {
      throw const NutritionPathwayActivationException(
        NutritionPathwayActivationFailure.clinicianReviewRequired,
      );
    }

    await repository.activate(
      draft,
      authorization: NutritionPathwayActivationAuthorization._(draft.pathwayId),
    );
  }
}

class DietPlanRepository {
  DietPlanRepository({required this.preferences, required this.schedule});

  final PreferencesRepository preferences;
  final NutritionGoalScheduleRepository schedule;

  static const activePathwayKey = 'activeNutritionPathway';
  static String draftKey(String pathwayId) =>
      'nutrition.dietDraft.v1.$pathwayId';

  Future<DietDraft> read(String pathwayId) async {
    if (nutritionPathwayForExactId(pathwayId) == null) {
      throw ArgumentError.value(pathwayId, 'pathwayId', 'Unknown pathway');
    }
    final saved = DietDraft.decode(await preferences.get(draftKey(pathwayId)));
    if (saved != null) {
      if (saved.pathwayId != pathwayId) {
        throw StateError('Stored draft does not match $pathwayId.');
      }
      return saved;
    }
    final preset = dietPresets[pathwayId];
    if (preset == null) {
      throw StateError('Pathway $pathwayId has no self-directed draft.');
    }
    return preset.toDraft();
  }

  Future<void> saveDraft(DietDraft draft) async {
    if (nutritionPathwayForExactId(draft.pathwayId) == null) {
      throw ArgumentError.value(
        draft.pathwayId,
        'draft.pathwayId',
        'Unknown pathway',
      );
    }
    if (draft.resolveWeek() == null) {
      throw ArgumentError.value(draft, 'draft', 'Invalid macro targets');
    }
    await preferences.set(draftKey(draft.pathwayId), draft.encode());
  }

  Future<String?> readActivePathway() async {
    final value = (await preferences.get(activePathwayKey))?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> activate(
    DietDraft draft, {
    required NutritionPathwayActivationAuthorization authorization,
  }) async {
    if (authorization.pathwayId != draft.pathwayId ||
        nutritionPathwayForExactId(draft.pathwayId) == null) {
      throw const NutritionPathwayActivationException(
        NutritionPathwayActivationFailure.invalidAuthorization,
      );
    }
    final targets = draft.resolveWeek();
    if (targets == null) throw ArgumentError.value(draft, 'draft');
    final current = await schedule.read();
    final nextSchedule = NutritionGoalSchedule(
      dayTargets: targets.map(
        (day, target) => MapEntry(day, target.toScheduledGoal()),
      ),
      mealTargets: current.mealTargets,
    );
    await preferences.mutate(
      set: {
        draftKey(draft.pathwayId): draft.encode(),
        nutritionGoalSchedulePreferenceKey: jsonEncode(nextSchedule.toJson()),
        activePathwayKey: draft.pathwayId,
      },
    );
  }

  /// Returns every nutrition consumer to the profile-derived recommendation.
  /// Meal-specific targets are retained because they are an independent user
  /// choice; the selected pathway and its seven day override are removed as
  /// one durable preference mutation.
  Future<void> resetToRecommended(NutritionGoalTarget target) async {
    if (!target.isValid) throw ArgumentError.value(target, 'target');
    final current = await schedule.read();
    final nextSchedule = NutritionGoalSchedule(
      dayTargets: {for (var day = 1; day <= 7; day += 1) day: target},
      mealTargets: current.mealTargets,
    );
    await preferences.mutate(
      set: {
        nutritionGoalSchedulePreferenceKey: jsonEncode(nextSchedule.toJson()),
      },
      remove: const [activePathwayKey],
    );
  }
}
