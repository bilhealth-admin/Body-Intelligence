import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/user_profile_provider.dart';
import '../domain/nutrient_dashboard.dart';
import '../../nutrition/domain/macro_gram_goals.dart';
import '../../nutrition/domain/percentage_nutrition_goals.dart';

abstract final class DashboardSectionIds {
  static const calories = 'calories';
  static const macros = 'macros';
  static const activity = 'activity';
  static const quickLog = 'quick_log';
  static const discover = 'discover';
  static const bestAction = 'best_action';
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
    progress,
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
  return ref.watch(preferencesRepositoryProvider).watch(key).map((value) {
    final parsed = double.tryParse(value ?? '');
    return validDashboardNutrientGoal(key, parsed) ? parsed : null;
  });
});

@visibleForTesting
bool validDashboardNutrientGoal(String key, double? value) {
  if (value == null || !value.isFinite || value <= 0) return false;
  if (key == 'goal.calories') return value <= 10000;
  if (key.endsWith('Percent')) return value <= 100;
  if (key == 'goal.sodium' || key == 'goal.potassium') {
    return value <= 1000000;
  }
  if (key == 'goal.fiber') return value <= 500;
  if (key == 'goal.proteinGrams' ||
      key == 'goal.carbsGrams' ||
      key == 'goal.fatGrams') {
    return value <= 1000;
  }
  return value <= 10000;
}

final dashboardMacroGramGoalsProvider = Provider<MacroGramGoals>((ref) {
  double? valid(double? value) =>
      value != null && value > 0 && value <= 1000 ? value : null;
  return MacroGramGoals(
    protein: valid(
      ref.watch(dashboardNutrientGoalProvider('goal.proteinGrams')).value,
    ),
    carbohydrates: valid(
      ref.watch(dashboardNutrientGoalProvider('goal.carbsGrams')).value,
    ),
    fat: valid(ref.watch(dashboardNutrientGoalProvider('goal.fatGrams')).value),
  );
});

final dashboardPercentageNutritionGoalsProvider =
    Provider<PercentageNutritionGoals?>((ref) {
      double value(String key) =>
          ref.watch(dashboardNutrientGoalProvider(key)).value ?? 0;
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
