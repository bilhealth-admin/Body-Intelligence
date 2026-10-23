import 'bil_smart_plan.dart';

/// Observed schedule facts only. An unconfirmed session is not proof that the
/// member did not exercise, and never authorizes extra training or less food.
final class BilSmartPlanWeekReview {
  BilSmartPlanWeekReview(BilSmartPlan plan, DateTime today) {
    final end = BilPlanDate.atMidnight(today);
    final start = end.subtract(const Duration(days: 6));
    for (final day in plan.days) {
      final date = BilPlanDate.parse(day.date);
      if (date.isBefore(start) || date.isAfter(end) || day.workout == null) {
        continue;
      }
      scheduled++;
      if (day.workout!.completed) {
        confirmed++;
      } else if (date.isBefore(end)) {
        unconfirmedPast++;
      } else {
        dueToday++;
      }
    }
  }
  int scheduled = 0, confirmed = 0, unconfirmedPast = 0, dueToday = 0;
}
