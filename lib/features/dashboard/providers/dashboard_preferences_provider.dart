import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../domain/nutrient_dashboard.dart';
import '../../nutrition/domain/macro_gram_goals.dart';
import '../../nutrition/domain/percentage_nutrition_goals.dart';
import '../../nutrition/domain/nutrition_goal_snapshot.dart';
import '../../nutrition/providers/nutrition_goal_snapshot_provider.dart';

abstract final class DashboardSectionIds {
  static const calories = 'calories';
  static const macros = 'macros';
  static const activity = 'activity';
  static const quickLog = 'quick_log';
  static const discover = 'discover';
  static const bestAction = 'best_action';
  // Retained only so older saved presets and isolated component previews can
  // still be decoded. The Daily Summary card is no longer part of the
  // production Dashboard and this id is intentionally absent from [all].
  static const progress = 'progress';
  static const connectedHealth = 'connected_health';
  static const bodyTwin = 'body_twin';
  static const aiCoach = 'ai_coach';

  static const all = <String>[
    calories,
    macros,
    activity,
    quickLog,
    discover,
    bestAction,
    connectedHealth,
    bodyTwin,
    aiCoach,
  ];

  static bool defaultVisible(String section) =>
      section != quickLog && section != bestAction;
}

final dashboardSectionVisibleProvider = StreamProvider.family<bool, String>((
  ref,
  section,
) {
  return ref
      .watch(preferencesRepositoryProvider)
      .watch('dashboard.section.$section')
      .map(
        (value) => value == null
            ? DashboardSectionIds.defaultVisible(section)
            : value == 'true',
      );
});

// Keep the subscription stable while the editor saves or rebuilds. Creating
// repository.watch() in build briefly unmounts the horizontal preset list.
final dashboardSelectedPresetProvider = StreamProvider<String?>((ref) {
  return ref.watch(preferencesRepositoryProvider).watch('dashboard.preset');
});

abstract final class DashboardNutrientGoalIds {
  static const protein = 'protein';
  static const carbohydrates = 'carbohydrates';
  static const fat = 'fat';
  static const fiber = 'fiber';
  static const sodium = 'sodium';
  static const potassium = 'potassium';

  static const all = <String>[
    protein,
    carbohydrates,
    fat,
    fiber,
    sodium,
    potassium,
  ];

  // Protein and carbohydrates are already represented in Today's primary
  // macro summary. Only genuinely additional nutrients are customizable cards.
  static const dashboardCards = <String>[fat, fiber, sodium, potassium];
}

final dashboardNutrientGoalCardsProvider = StreamProvider<Set<String>>((ref) {
  return ref
      .watch(preferencesRepositoryProvider)
      .watch('dashboard.nutrientGoalCards')
      .map(
        (value) => (value ?? '')
            .split(',')
            .where(DashboardNutrientGoalIds.dashboardCards.contains)
            .toSet(),
      );
});

/// The Diary setting controls which nutrition card is shown first on Today.
/// Values intentionally match the persisted choices in ReferenceDiarySettingsPage.
final dashboardNutrientDashboardProvider = StreamProvider<String>((ref) {
  return ref
      .watch(preferencesRepositoryProvider)
      .watch('diary.nutrientDashboard')
      .map((value) => value ?? 'Calories and macros');
});

final dashboardNutrientGoalProvider = StreamProvider.family<double?, String>((
  ref,
  key,
) {
  final snapshot = ref.watch(nutritionGoalSnapshotProvider);
  return snapshot.when(
    data: (value) => Stream.value(value.goals[key]?.value),
    error: (error, stack) => Stream.error(error, stack),
    loading: () => const Stream.empty(),
  );
});

/// Shared validation for persisted goals and the user-facing goal editor.
bool validDashboardNutrientGoal(String key, double? value) {
  return NutritionGoalSnapshot.technicallyValid(key, value);
}

final dashboardMacroGramGoalsProvider = Provider<MacroGramGoals>((ref) {
  final snapshot = ref.watch(nutritionGoalCurrentSnapshotProvider);
  double? valid(double? value) =>
      value != null && value >= 0 && value <= 2500 ? value : null;
  return MacroGramGoals(
    protein: valid(snapshot?.goals['goal.proteinGrams']?.value),
    carbohydrates: valid(snapshot?.goals['goal.carbsGrams']?.value),
    fat: valid(snapshot?.goals['goal.fatGrams']?.value),
  );
});

final dashboardPercentageNutritionGoalsProvider =
    Provider<PercentageNutritionGoals?>((ref) {
      final snapshot = ref.watch(nutritionGoalCurrentSnapshotProvider);
      double value(String key) => snapshot?.goals[key]?.value ?? 0;
      return PercentageNutritionGoals.resolve(
        calories: value('goal.calories'),
        carbohydratesPercent: value('goal.carbsPercent'),
        proteinPercent: value('goal.proteinPercent'),
        fatPercent: value('goal.fatPercent'),
      );
    });

final dashboardNutrientPresetProvider = Provider<NutrientDashboardPreset>((
  ref,
) {
  final stored = ref.watch(dashboardNutrientDashboardProvider).value;
  return NutrientDashboardPreset.parse(stored);
});
