part of 'bil_smart_plan.dart';

/// Immutable proposals, persisted only by a confirmed owner-bound native flow.
extension BilSmartPlanAdaptation on BilSmartPlan {
  BilSmartPlan swapMealDates({
    required DateTime date,
    required DateTime target,
    required BilPlanMealSlot slot,
    required DateTime now,
  }) {
    final source = onDate(date);
    final destination = onDate(target);
    if (status != BilPlanStatus.active ||
        source == null ||
        destination == null ||
        source.date == destination.date ||
        BilPlanDate.atMidnight(date).isBefore(BilPlanDate.atMidnight(now)) ||
        BilPlanDate.atMidnight(target).isBefore(BilPlanDate.atMidnight(now))) {
      throw StateError('smart_plan_cannot_swap_meal_dates');
    }
    final a = source.meals.where((m) => m.slot == slot).single;
    final b = destination.meals.where((m) => m.slot == slot).single;
    if (a.recipeId == b.recipeId) {
      throw StateError('smart_plan_identical_meals');
    }
    final next = days.map(
      (day) => day.date == source.date || day.date == destination.date
          ? BilPlanDay(
              date: day.date,
              phase: day.phase,
              workout: day.workout,
              meals: day.meals.map(
                (m) => m.slot == slot
                    ? BilPlanMeal(
                        slot: slot,
                        recipeId: day.date == source.date
                            ? b.recipeId
                            : a.recipeId,
                      )
                    : m,
              ),
            )
          : day,
    );
    return _updated(
      status: status,
      days: next.toList(growable: false),
      now: now,
      reason: BilPlanChangeReason.mealSwap,
    );
  }

  BilSmartPlan replaceWorkout({
    required DateTime date,
    required BilPlanWorkout replacement,
    required DateTime now,
    required BilPlanChangeReason reason,
  }) {
    final day = onDate(date);
    if (status != BilPlanStatus.active ||
        day?.workout == null ||
        day!.workout!.completed ||
        replacement.completed ||
        replacement.effort != null ||
        replacement.templateId == day.workout!.templateId ||
        BilPlanDate.atMidnight(date).isBefore(BilPlanDate.atMidnight(now)) ||
        !const {
          BilPlanChangeReason.equipment,
          BilPlanChangeReason.fatigue,
        }.contains(reason)) {
      throw StateError('smart_plan_cannot_replace_workout');
    }
    return _updated(
      status: status,
      days: days
          .map((d) => d.date == day.date ? d.withWorkout(replacement) : d)
          .toList(growable: false),
      now: now,
      reason: reason,
    );
  }
}
