import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../connected_health/connected_health_model.dart';
import '../../connected_health/providers/connected_health_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../domain/exercise_calorie_policy.dart';

const exerciseCaloriesIncludedPreferenceKey =
    'nutrition.exerciseCalories.includeInRemaining.v1';
const exerciseMacrosAdjustedPreferenceKey =
    'nutrition.exerciseCalories.adjustMacros.v1';

final exerciseCaloriePreferencesProvider =
    StreamProvider<ExerciseCaloriePreferences>((ref) async* {
      final repository = ref.watch(preferencesRepositoryProvider);
      await for (final includeValue in repository.watch(
        exerciseCaloriesIncludedPreferenceKey,
      )) {
        final adjustValue = await repository.get(
          exerciseMacrosAdjustedPreferenceKey,
        );
        yield ExerciseCaloriePreferences(
          includeInRemainingGoal: includeValue == 'true',
          adjustMacroGoals: adjustValue == 'true',
        );
      }
    });

AuthoritativeExerciseEnergy? authoritativeExerciseEnergyForDay(
  ConnectedHealthSnapshot? snapshot,
  DateTime day,
) {
  if (snapshot == null || !snapshot.deviceVerified) return null;
  final candidates = snapshot.signals.where(
    (signal) => signal.key == 'activeEnergy' && signal.unit == 'kcal',
  );
  AuthoritativeExerciseEnergy? selected;
  for (final signal in candidates) {
    final candidate = AuthoritativeExerciseEnergy(
      kcal: signal.value,
      observedAt: signal.observedAt,
      source: signal.source,
      confidence: signal.confidence,
    );
    if (!candidate.isValidFor(day)) continue;
    if (selected == null || candidate.observedAt.isAfter(selected.observedAt)) {
      selected = candidate;
    }
  }
  return selected;
}

final todayAuthoritativeExerciseEnergyProvider =
    Provider<AsyncValue<AuthoritativeExerciseEnergy?>>((ref) {
      return ref
          .watch(connectedHealthProvider)
          .whenData(
            (snapshot) =>
                authoritativeExerciseEnergyForDay(snapshot, DateTime.now()),
          );
    });

Future<void> saveExerciseCaloriePreferences(
  WidgetRef ref,
  ExerciseCaloriePreferences preferences,
) async {
  final repository = ref.read(preferencesRepositoryProvider);
  await repository.setMany({
    exerciseCaloriesIncludedPreferenceKey: preferences.includeInRemainingGoal
        .toString(),
    exerciseMacrosAdjustedPreferenceKey: preferences.adjustMacroGoals
        .toString(),
  });
  ref.invalidate(exerciseCaloriePreferencesProvider);
}
