import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/plan_engine.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../domain/nutrient_daily_references.dart';
import '../domain/nutrition_pace_intent.dart';

/// Repository identity scopes retained stream data to one local owner visit.
final nutritionPaceIntentProvider = StreamProvider.autoDispose
    .family<NutritionPaceIntent, PreferencesRepository>((ref, repository) {
      return repository
          .watch(NutritionPaceIntent.storageKey)
          .map(NutritionPaceIntent.decode);
    }, retry: (_, _) => null);

/// Recomputed from the same body/plan inputs used by onboarding and analytics.
/// These are fallbacks only: neither profile changes nor a refresh writes over
/// a user's saved goals. Clearing an override restores this live recommendation.
final nutritionGoalDefaultsProvider = Provider<Map<String, double>>((ref) {
  final defaults = <String, double>{...NutrientDailyReferences.values};
  final profile = ref.watch(userProfileProvider).asData?.value;
  final goalState = ref.watch(activeGoalProvider);
  final weight = ref.watch(effectiveCurrentWeightProvider);
  if (profile == null) return defaults;
  final planState = ref.watch(planSettingProvider(profile.uuid));
  // A failed/unfinished read is not the same as a known absent goal. Retain
  // the fixed label references, but never invent a maintenance recommendation.
  // Saved manual targets are resolved independently by NutritionGoalSnapshot.
  if (planState.isLoading ||
      planState.hasError ||
      goalState.hasError ||
      (goalState.isLoading &&
          (!goalState.isRefreshing || !goalState.hasValue))) {
    return Map.unmodifiable(defaults);
  }
  final goal = goalState.asData?.value;
  final plan = planState.asData?.value;
  final body = BodyProfile(
    age: profile.age,
    gender: profile.gender,
    height: profile.height,
    weight: weight ?? profile.currentWeight,
    targetWeight: profile.targetWeight,
    activityLevel: profile.activityLevel,
    exercises: profile.exercises,
    goalType: goal?.type ?? 'maintain',
    waistCm: profile.waist,
    neckCm: profile.neck,
  );
  final repository = ref.watch(preferencesRepositoryProvider);
  // .value retains this repository's last valid data on refresh/read failure.
  // Initial pending/corrupt reads cannot masquerade as a known legacy absence.
  final pace = ref.watch(
    nutritionPaceIntentProvider(repository).select((state) => state.value),
  );
  final recommendation = pace == null ? null : PlanEngine.recommend(body);
  final target = recommendation?.targets;
  final paced = pace?.targetsFor(
    tdee: recommendation!.tdee,
    goalType: body.goalType,
  );
  final calories =
      (plan?.overrideCalories ?? paced?.calories ?? target?.calories)
          ?.toDouble();
  final protein = (plan?.overrideProtein ?? target?.protein)?.toDouble();
  final fat = (plan?.overrideFats ?? paced?.fats ?? target?.fats)?.toDouble();
  if (calories == null || protein == null || fat == null) {
    return Map.unmodifiable(defaults);
  }
  final carbs = (plan?.overrideCarbs ?? (calories - protein * 4 - fat * 9) / 4)
      .toDouble();
  if (calories > 0 &&
      calories <= 10000 &&
      protein >= 0 &&
      fat >= 0 &&
      carbs >= 0) {
    defaults.addAll({
      'goal.calories': calories,
      'goal.proteinGrams': protein,
      'goal.carbsGrams': carbs,
      'goal.fatGrams': fat,
      'goal.proteinPercent': protein * 400 / calories,
      'goal.carbsPercent': carbs * 400 / calories,
      'goal.fatPercent': fat * 900 / calories,
    });
  }
  return Map.unmodifiable(defaults);
});
