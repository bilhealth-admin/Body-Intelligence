import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../nutrition/domain/nutrition_goal_snapshot.dart';
import '../domain/bil_smart_plan.dart';
import '../domain/bil_smart_plan_nutrition.dart';

/// Same saved day/goal authorities as the nutrition screens. Unreviewed legacy
/// overrides and profile suggestions are never silently treated as consented
/// targets for a new plan. This reader has no preference/goal write methods.
abstract final class BilSmartPlanNutritionGoals {
  static Future<NutritionGoalSnapshot> readSavedSnapshot(
    PreferencesRepository preferences,
  ) async => NutritionGoalSnapshot.resolve(
    await preferences.watchSnapshot(NutritionGoalSnapshot.storageKeys).first,
    const {},
  );
  static BilPlanNutrients? forDate({
    required DateTime date,
    required NutritionGoalSnapshot snapshot,
    required NutritionGoalSchedule schedule,
  }) {
    final scheduled = schedule.targetFor(date);
    if (scheduled != null) {
      return BilPlanNutrients(
        values: {
          'kcal': scheduled.calories,
          'proteinG': scheduled.proteinGrams,
          'carbohydrateG': scheduled.carbsGrams,
          'fatG': scheduled.fatGrams,
        },
        source: 'saved_daily_nutrition_schedule',
      );
    }
    final values = <String, double>{};
    for (final entry in const {
      'goal.calories': 'kcal',
      'goal.proteinGrams': 'proteinG',
      'goal.carbsGrams': 'carbohydrateG',
      'goal.fatGrams': 'fatG',
    }.entries) {
      final goal = snapshot.goals[entry.key];
      if (goal != null &&
          goal.isManual &&
          !goal.needsReview &&
          goal.value != null &&
          goal.value!.isFinite &&
          goal.value! > 0) {
        values[entry.value] = goal.value!;
      }
    }
    final calories = values['kcal'];
    if (calories == null) return null;
    for (final entry in const {
      'goal.proteinPercent': ('proteinG', 400),
      'goal.carbsPercent': ('carbohydrateG', 400),
      'goal.fatPercent': ('fatG', 900),
    }.entries) {
      final goal = snapshot.goals[entry.key];
      if (!values.containsKey(entry.value.$1) &&
          goal != null &&
          goal.isManual &&
          !goal.needsReview &&
          goal.value != null &&
          goal.value! > 0 &&
          goal.value! <= 100) {
        values[entry.value.$1] = calories * goal.value! / entry.value.$2;
      }
    }
    return BilPlanNutrients(
      values: values,
      source: 'saved_manual_nutrition_goals',
    );
  }

  static Map<String, BilPlanNutrients> forPlan({
    required DateTime start,
    required BilPlanHorizon horizon,
    required NutritionGoalSnapshot snapshot,
    required NutritionGoalSchedule schedule,
  }) {
    final anchor = BilPlanDate.atMidnight(start);
    final targets = <String, BilPlanNutrients>{};
    for (var day = 0; day < BilPlanDate.durationDays(horizon, anchor); day++) {
      final date = anchor.add(Duration(days: day));
      final target = forDate(
        date: date,
        snapshot: snapshot,
        schedule: schedule,
      );
      if (target != null) targets[BilPlanDate.iso(date)] = target;
    }
    return targets;
  }
}
