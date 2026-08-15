import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../nutrition/domain/macro_gram_goals.dart';
import '../../nutrition/domain/percentage_nutrition_goals.dart';

/// Resolves the nutrition targets exposed to Coach from the same persisted
/// goal contracts consumed by Today, Diary and Nutrition Analytics.
abstract final class CoachNutritionGoalResolver {
  static Map<String, double> resolve({
    required DateTime localDay,
    required Map<String, double> fallback,
    required NutritionGoalSchedule schedule,
    PercentageNutritionGoals? percentageGoals,
    MacroGramGoals gramGoals = const MacroGramGoals(),
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

    return <String, double>{
      ...fallback,
      'caloriesKcal': calories,
      'proteinG':
          gramGoals.protein ??
          percentages?.proteinGrams ??
          (fallback['proteinG'] ?? 0),
      'carbsG':
          gramGoals.carbohydrates ??
          percentages?.carbohydratesGrams ??
          (fallback['carbsG'] ?? 0),
      'fatG': gramGoals.fat ?? percentages?.fatGrams ?? (fallback['fatG'] ?? 0),
    };
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
