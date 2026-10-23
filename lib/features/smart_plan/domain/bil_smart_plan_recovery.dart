part of 'bil_smart_plan.dart';

bool _homeRecoverySequenceIsSafe(BilSmartPlan plan, Iterable<BilPlanDay> days) {
  if (plan.setup?.environment != BilPlanEnvironment.home ||
      !plan.days.any(
        (day) =>
            day.workout?.templateId.startsWith('home-strength-v1-') == true,
      )) {
    return true; // Legacy plans stay readable for explicit review.
  }
  // Civil dates, never elapsed local hours across a DST boundary.
  final dates = days.where((day) => day.workout != null).map((day) {
    final parsed = BilPlanDate.parse(day.date);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }).toList()..sort();
  final start = BilPlanDate.parse(plan.startDate);
  final anchor = DateTime.utc(start.year, start.month, start.day);
  final weeks = <int, int>{};
  for (var index = 0; index < dates.length; index++) {
    if (index > 0 && dates[index].difference(dates[index - 1]).inDays < 2) {
      return false;
    }
    final week = dates[index].difference(anchor).inDays ~/ 7;
    final count = weeks.update(week, (value) => value + 1, ifAbsent: () => 1);
    if (count > 3) return false;
  }
  return true;
}

extension BilSmartPlanHomeRecovery on BilSmartPlan {
  bool get hasSafeHomeRecovery => _homeRecoverySequenceIsSafe(this, days);

  /// Preview availability only. The actual domain mutation repeats the guard
  /// before creating a revision; UI filtering is never its only protection.
  bool recoveryAllowsMove({required DateTime date, required DateTime target}) {
    final source = days.indexWhere((day) => day.date == BilPlanDate.iso(date));
    final destination = days.indexWhere(
      (day) => day.date == BilPlanDate.iso(target),
    );
    if (source < 0 ||
        destination < 0 ||
        days[source].workout == null ||
        days[destination].workout != null) {
      return false;
    }
    final preview = List<BilPlanDay>.of(days);
    preview[source] = BilPlanDay(
      date: days[source].date,
      phase: days[source].phase,
      meals: days[source].meals,
    );
    preview[destination] = days[destination].withWorkout(days[source].workout!);
    return _homeRecoverySequenceIsSafe(this, preview);
  }
}
