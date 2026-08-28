import 'dart:math' as math;

enum GoalTimelineState { alreadyAtGoal, maintain, losing, gaining }

final class GoalTimelineEstimate {
  const GoalTimelineEstimate({
    required this.state,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.adherenceAssumption,
    required this.plannedWeeklyLowKg,
    required this.plannedWeeklyHighKg,
    this.minimumWeeks,
    this.maximumWeeks,
    this.earliestDate,
    this.latestDate,
  });

  final GoalTimelineState state;
  final double currentWeightKg;
  final double targetWeightKg;
  final double adherenceAssumption;
  final double plannedWeeklyLowKg;
  final double plannedWeeklyHighKg;
  final int? minimumWeeks;
  final int? maximumWeeks;
  final DateTime? earliestDate;
  final DateTime? latestDate;

  bool get hasDateRange => earliestDate != null && latestDate != null;
}

abstract final class GoalTimelineEstimator {
  static const double defaultAdherenceAssumption = 0.8;
  static const double atGoalToleranceKg = 0.1;

  static GoalTimelineEstimate estimate({
    required double currentWeightKg,
    required double targetWeightKg,
    required String goalType,
    required DateTime asOf,
    double adherenceAssumption = defaultAdherenceAssumption,
  }) {
    if (!currentWeightKg.isFinite || currentWeightKg <= 0) {
      throw ArgumentError.value(currentWeightKg, 'currentWeightKg');
    }
    if (!targetWeightKg.isFinite || targetWeightKg <= 0) {
      throw ArgumentError.value(targetWeightKg, 'targetWeightKg');
    }
    if (!adherenceAssumption.isFinite ||
        adherenceAssumption < 0.5 ||
        adherenceAssumption > 1) {
      throw ArgumentError.value(adherenceAssumption, 'adherenceAssumption');
    }

    final distance = (currentWeightKg - targetWeightKg).abs();
    if (distance <= atGoalToleranceKg) {
      return GoalTimelineEstimate(
        state: GoalTimelineState.alreadyAtGoal,
        currentWeightKg: currentWeightKg,
        targetWeightKg: targetWeightKg,
        adherenceAssumption: adherenceAssumption,
        plannedWeeklyLowKg: 0,
        plannedWeeklyHighKg: 0,
      );
    }
    if (goalType == 'maintain') {
      return GoalTimelineEstimate(
        state: GoalTimelineState.maintain,
        currentWeightKg: currentWeightKg,
        targetWeightKg: targetWeightKg,
        adherenceAssumption: adherenceAssumption,
        plannedWeeklyLowKg: 0,
        plannedWeeklyHighKg: 0,
      );
    }

    final losing = targetWeightKg < currentWeightKg;
    // These are conservative planning bands, not observed or promised rates.
    // Loss is capped below 0.75 kg/week; gain below 0.30 kg/week. The displayed
    // timeline then applies the explicit adherence assumption to both bounds.
    final rawLow = losing
        ? (currentWeightKg * 0.003).clamp(0.15, 0.35).toDouble()
        : (currentWeightKg * 0.0012).clamp(0.08, 0.14).toDouble();
    final rawHigh = losing
        ? (currentWeightKg * 0.0075).clamp(0.30, 0.75).toDouble()
        : (currentWeightKg * 0.003).clamp(0.18, 0.30).toDouble();
    final effectiveLow = rawLow * adherenceAssumption;
    final effectiveHigh = rawHigh * adherenceAssumption;
    final minimumWeeks = math.max(1, (distance / effectiveHigh).ceil());
    final maximumWeeks = math.max(
      minimumWeeks,
      (distance / effectiveLow).ceil(),
    );
    final start = DateTime(asOf.year, asOf.month, asOf.day);
    return GoalTimelineEstimate(
      state: losing ? GoalTimelineState.losing : GoalTimelineState.gaining,
      currentWeightKg: currentWeightKg,
      targetWeightKg: targetWeightKg,
      adherenceAssumption: adherenceAssumption,
      plannedWeeklyLowKg: effectiveLow,
      plannedWeeklyHighKg: effectiveHigh,
      minimumWeeks: minimumWeeks,
      maximumWeeks: maximumWeeks,
      earliestDate: start.add(Duration(days: minimumWeeks * 7)),
      latestDate: start.add(Duration(days: maximumWeeks * 7)),
    );
  }
}
