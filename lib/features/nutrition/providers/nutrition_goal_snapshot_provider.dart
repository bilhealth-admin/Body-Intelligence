import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../domain/nutrition_goal_snapshot.dart';
import 'nutrition_goal_defaults_provider.dart';

/// Drift emits a complete transaction, rather than one event per goal key.
/// Failure remains a typed failure snapshot: it is never an absent override.
final nutritionGoalSnapshotProvider = StreamProvider<NutritionGoalSnapshot>((
  ref,
) async* {
  final defaults = ref.watch(nutritionGoalDefaultsProvider);
  final repository = ref.watch(preferencesRepositoryProvider);
  try {
    await for (final stored in repository.watchSnapshot(
      NutritionGoalSnapshot.storageKeys,
    )) {
      yield NutritionGoalSnapshot.resolve(stored, defaults);
    }
  } on Object {
    yield NutritionGoalSnapshot.resolve(
      const {},
      defaults,
      storageFailed: true,
    );
  }
});

final nutritionGoalCurrentSnapshotProvider = Provider<NutritionGoalSnapshot?>((
  ref,
) {
  final snapshot = ref.watch(nutritionGoalSnapshotProvider);
  return snapshot.isLoading || snapshot.hasError ? null : snapshot.value;
});

final nutritionMacroGoalsNeedReviewProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(nutritionGoalCurrentSnapshotProvider);
  return snapshot == null ||
      NutritionGoalSnapshot.macroKeys.any(
        (key) =>
            snapshot.goals[key]!.needsReview ||
            snapshot.goals[key]!.value == null,
      );
});

/// An account visit retires pending editors even after A -> B -> A returns to
/// the same database object. This token never conveys authorization itself.
final nutritionGoalOwnerVisitProvider = Provider<Object>((ref) {
  ref.watch(preferencesRepositoryProvider);
  return Object();
});
