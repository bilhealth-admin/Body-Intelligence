import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../nutrition/domain/macro_gram_goals.dart';
import '../../nutrition/domain/percentage_nutrition_goals.dart';

class CoachNutritionGoalResolution {
  const CoachNutritionGoalResolution({
    required this.targets,
    required this.sources,
  });

  final Map<String, double> targets;
  final Map<String, String> sources;
}

/// Resolves the nutrition targets exposed to Coach from the same persisted
/// goal contracts consumed by Today, Diary and Nutrition Analytics.
abstract final class CoachNutritionGoalResolver {
  static Map<String, double> resolve({
    required DateTime localDay,
    required Map<String, double> fallback,
    required NutritionGoalSchedule schedule,
    PercentageNutritionGoals? percentageGoals,
    MacroGramGoals gramGoals = const MacroGramGoals(),
  }) => resolveWithSources(
    localDay: localDay,
    fallback: fallback,
    schedule: schedule,
    percentageGoals: percentageGoals,
    gramGoals: gramGoals,
  ).targets;

  static CoachNutritionGoalResolution resolveWithSources({
    required DateTime localDay,
    required Map<String, double> fallback,
    required NutritionGoalSchedule schedule,
    PercentageNutritionGoals? percentageGoals,
    MacroGramGoals gramGoals = const MacroGramGoals(),
    Map<String, String> fallbackSources = const <String, String>{},
  }) {
    final scheduled = schedule.targetFor(localDay);
    final calories =
        scheduled?.calories ??
        percentageGoals?.calories ??
        (fallback['caloriesKcal'] ?? 0);
    final scheduledPercentages = scheduled == null
        ? percentageGoals
        : PercentageNutritionGoals.resolve(
            calories: scheduled.calories,
            carbohydratesPercent: scheduled.carbsPercent,
            proteinPercent: scheduled.proteinPercent,
            fatPercent: scheduled.fatPercent,
          );
    final percentages = scheduledPercentages ?? percentageGoals;
    // A selected diet pathway is the same day-level authority consumed by
    // Today, Diary, Analytics and Dashboard. Historical gram preferences only
    // win when no scheduled pathway target exists; otherwise Coach would
    // explain a different macro plan from the rest of the app.
    final scheduledWins = scheduled != null;

    final targets = <String, double>{
      ...fallback,
      'caloriesKcal': calories,
      'proteinG':
          (scheduledWins ? null : gramGoals.protein) ??
          percentages?.proteinGrams ??
          (fallback['proteinG'] ?? 0),
      'carbsG':
          (scheduledWins ? null : gramGoals.carbohydrates) ??
          percentages?.carbohydratesGrams ??
          (fallback['carbsG'] ?? 0),
      'fatG':
          (scheduledWins ? null : gramGoals.fat) ??
          percentages?.fatGrams ??
          (fallback['fatG'] ?? 0),
    };
    final sources = <String, String>{
      for (final key in targets.keys)
        key: fallbackSources[key] ?? 'fallback_calculation',
      'caloriesKcal': scheduled != null
          ? 'scheduled_daily_goal'
          : percentageGoals != null
          ? 'saved_percentage_goal'
          : fallbackSources['caloriesKcal'] ?? 'fallback_calculation',
      'proteinG': scheduled != null
          ? 'scheduled_percentage_goal'
          : gramGoals.protein != null
          ? 'saved_gram_goal'
          : percentages != null
          ? 'saved_percentage_goal'
          : fallbackSources['proteinG'] ?? 'fallback_calculation',
      'carbsG': scheduled != null
          ? 'scheduled_percentage_goal'
          : gramGoals.carbohydrates != null
          ? 'saved_gram_goal'
          : percentages != null
          ? 'saved_percentage_goal'
          : fallbackSources['carbsG'] ?? 'fallback_calculation',
      'fatG': scheduled != null
          ? 'scheduled_percentage_goal'
          : gramGoals.fat != null
          ? 'saved_gram_goal'
          : percentages != null
          ? 'saved_percentage_goal'
          : fallbackSources['fatG'] ?? 'fallback_calculation',
    };
    return CoachNutritionGoalResolution(targets: targets, sources: sources);
  }

  static Map<String, Map<String, double>> mealTargets(
    NutritionGoalSchedule schedule,
  ) => schedule.mealTargets.map(
    (key, value) => MapEntry(key, <String, double>{
      'caloriesKcal': value.calories,
      'carbsPercent': value.carbsPercent,
      'proteinPercent': value.proteinPercent,
      'fatPercent': value.fatPercent,
    }),
  );
}
