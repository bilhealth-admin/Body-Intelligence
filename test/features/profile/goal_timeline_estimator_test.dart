import 'package:flutter_test/flutter_test.dart';

import 'package:body_intelligence_log/features/profile/domain/goal_timeline_estimator.dart';
import 'package:body_intelligence_log/features/profile/plan_navigation_contract.dart';

void main() {
  group('goal timeline estimator', () {
    final asOf = DateTime(2026, 8, 24);

    test('loss uses a conservative adherence-adjusted range and dates', () {
      final estimate = GoalTimelineEstimator.estimate(
        currentWeightKg: 100,
        targetWeightKg: 90,
        goalType: 'lose',
        asOf: asOf,
      );

      expect(estimate.state, GoalTimelineState.losing);
      expect(estimate.adherenceAssumption, 0.8);
      expect(estimate.plannedWeeklyLowKg, closeTo(0.24, 0.0001));
      expect(estimate.plannedWeeklyHighKg, closeTo(0.6, 0.0001));
      expect(estimate.plannedWeeklyHighKg, lessThanOrEqualTo(0.600001));
      expect(estimate.minimumWeeks, 17);
      expect(estimate.maximumWeeks, 42);
      expect(estimate.earliestDate, asOf.add(const Duration(days: 17 * 7)));
      expect(estimate.latestDate, asOf.add(const Duration(days: 42 * 7)));
    });

    test('gain uses a slower non-aggressive planning range', () {
      final estimate = GoalTimelineEstimator.estimate(
        currentWeightKg: 60,
        targetWeightKg: 66,
        goalType: 'gain',
        asOf: asOf,
      );

      expect(estimate.state, GoalTimelineState.gaining);
      expect(estimate.plannedWeeklyLowKg, closeTo(0.064, 0.0001));
      expect(estimate.plannedWeeklyHighKg, closeTo(0.144, 0.0001));
      expect(estimate.plannedWeeklyHighKg, lessThanOrEqualTo(0.24));
      expect(estimate.hasDateRange, isTrue);
    });

    test('already-at-goal and maintenance do not promise a date', () {
      final atGoal = GoalTimelineEstimator.estimate(
        currentWeightKg: 70.05,
        targetWeightKg: 70,
        goalType: 'lose',
        asOf: asOf,
      );
      final maintain = GoalTimelineEstimator.estimate(
        currentWeightKg: 72,
        targetWeightKg: 70,
        goalType: 'maintain',
        asOf: asOf,
      );

      expect(atGoal.state, GoalTimelineState.alreadyAtGoal);
      expect(atGoal.hasDateRange, isFalse);
      expect(maintain.state, GoalTimelineState.maintain);
      expect(maintain.hasDateRange, isFalse);
    });
  });

  test('plan origin parser accepts only profile and dashboard', () {
    expect(PlanPageOrigin.fromQuery('profile'), PlanPageOrigin.profile);
    expect(PlanPageOrigin.fromQuery('dashboard'), PlanPageOrigin.dashboard);
    expect(PlanPageOrigin.fromQuery('/admin'), PlanPageOrigin.dashboard);
    expect(PlanPageOrigin.fromQuery(null), PlanPageOrigin.dashboard);
    expect(PlanPageOrigin.profile.returnLocation, '/profile-settings');
    expect(PlanPageOrigin.dashboard.returnLocation, '/dashboard');
  });
}
