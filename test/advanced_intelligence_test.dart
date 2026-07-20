import 'package:body_intelligence_log/engine/body_twin_engine.dart';
import 'package:body_intelligence_log/engine/data_honesty_engine.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/engine/personal_baseline_engine.dart';
import 'package:body_intelligence_log/engine/what_changed_engine.dart';
import 'package:body_intelligence_log/engine/recovery_engine.dart';
import 'package:body_intelligence_log/engine/weekly_review_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data honesty states exact missing evidence', () {
    final report = DataHonestyEngine.evaluate(
      observationDays: 3,
      weightDays: 2,
      nutritionDays: 1,
      waterDays: 2,
      consistentConditionDays: 1,
    );
    expect(report.reliability, DataReliability.insufficient);
    expect(report.missing, isNotEmpty);
    expect(report.score, inInclusiveRange(0, 100));
  });

  test('one best action prioritizes missing check-in without overload', () {
    final action = OneBestActionEngine.choose(
      weighedToday: false,
      loggingComplete: false,
      protein: 0,
      proteinTarget: 120,
      waterMl: 0,
      waterTarget: 2500,
      trackedDays: 0,
    );
    expect(action.type, BestActionType.weighIn);
    expect(action.evidence, hasLength(1));
  });

  test('one best action stops repeating advice rated unhelpful twice', () {
    final action = OneBestActionEngine.choose(
      weighedToday: true,
      loggingComplete: true,
      protein: 20,
      proteinTarget: 120,
      waterMl: 800,
      waterTarget: 2500,
      trackedDays: 20,
      suppressedTypes: const {BestActionType.protein},
    );
    expect(action.type, BestActionType.hydration);
  });

  test(
    'suppressed hydration advice yields explicit type-specific memory explanation',
    () {
      final action = OneBestActionEngine.choose(
        weighedToday: true,
        loggingComplete: true,
        protein: 120,
        proteinTarget: 120,
        waterMl: 2500,
        waterTarget: 2500,
        trackedDays: 20,
        suppressedTypes: const {BestActionType.hydration},
      );
      expect(action.type, BestActionType.none);
      expect(action.title, contains('hydration'));
      expect(action.reason, contains('Hydration advice was paused'));
      expect(
        action.evidence,
        contains('Hydration recommendation was intentionally not repeated today'),
      );
    },
  );

  test(
    'suppressed protein advice yields explicit type-specific memory explanation',
    () {
      final action = OneBestActionEngine.choose(
        weighedToday: true,
        loggingComplete: true,
        protein: 120,
        proteinTarget: 120,
        waterMl: 2500,
        waterTarget: 2500,
        trackedDays: 20,
        suppressedTypes: const {BestActionType.protein},
      );
      expect(action.type, BestActionType.none);
      expect(action.title, contains('protein'));
      expect(action.reason, contains('Protein advice was paused'));
      expect(
        action.evidence,
        contains('Protein recommendation was intentionally not repeated today'),
      );
    },
  );

  test('body twin refuses a scenario until data is sufficient', () {
    final report = BodyTwinEngine.simulate(
      calorieTarget: 2000,
      tdee: 2400,
      weightDays: 3,
      nutritionDays: 2,
      observationDays: 5,
    );
    expect(report.sufficient, isFalse);
    expect(report.scenario, isNull);
    expect(report.requiredData, isNotEmpty);
  });

  test('body twin provides cautious range and assumptions when sufficient', () {
    final report = BodyTwinEngine.simulate(
      calorieTarget: 2000,
      tdee: 2400,
      weightDays: 10,
      nutritionDays: 10,
      observationDays: 16,
    );
    expect(report.sufficient, isTrue);
    expect(
      report.scenario!.cautiousLowKg,
      lessThan(report.scenario!.cautiousHighKg),
    );
    expect(report.scenario!.assumptions, isNotEmpty);
  });

  test('what changed avoids certainty after a large single-day jump', () {
    final report = WhatChangedEngine.compare(
      chronologicalWeights: const [80, 81.2],
      comparableConditions: false,
      contextTypes: const ['travel', 'poorSleep'],
    );
    expect(report.interpretation, ChangeInterpretation.likelyNoise);
    expect(report.alternatives, contains('Water and glycogen'));
    expect(report.summary, isNot(contains('fat gain')));
    expect(report.evidence, contains('Context recorded: travel'));
    expect(
      report.alternatives,
      contains('travel may be relevant, but this record does not prove cause'),
    );
  });

  test('recovery mode welcomes return without requiring backfill', () {
    final report = RecoveryEngine.evaluate(
      now: DateTime(2026, 7, 18),
      lastTrackedAt: DateTime(2026, 7, 8),
    );
    expect(report.state, RecoveryState.gentleReturn);
    expect(report.title, contains('no need to fill'));
    expect(report.actions, contains('Start today fresh'));
  });

  test('weekly review discloses missing data and avoids tissue claims', () {
    final review = WeeklyReviewEngine.evaluate(
      weightDays: 3,
      nutritionDays: 4,
      waterDays: 2,
      contextDays: 1,
      weeklyWeightChangeKg: 0.8,
    );
    expect(review.missingData, isNotEmpty);
    expect(review.summary, contains('does not identify fat or muscle'));
    expect(review.nextDecision, contains('before changing the plan'));
  });

  test('personal baseline compares the user only with their own records', () {
    final calories = <String, double>{
      for (var day = 1; day <= 14; day++)
        '2026-07-${day.toString().padLeft(2, '0')}': day < 8 ? 2000 : 1800,
    };
    final report = PersonalBaselineEngine.evaluate(
      caloriesByDay: calories,
      proteinByDay: const {},
      sodiumByDay: const {},
      waterByDay: const {},
      weightByDay: const {},
      currentStartDay: '2026-07-08',
    );
    expect(report.sufficient, isTrue);
    expect(report.comparisons.single.baseline, 2000);
    expect(report.comparisons.single.current, 1800);
    expect(report.missingEvidence, isNotEmpty);
  });

  test('personal baseline refuses population substitutes when sparse', () {
    final report = PersonalBaselineEngine.evaluate(
      caloriesByDay: const {'2026-07-18': 1800},
      proteinByDay: const {},
      sodiumByDay: const {},
      waterByDay: const {},
      weightByDay: const {},
      currentStartDay: '2026-07-13',
    );
    expect(report.confidence, BaselineConfidence.insufficient);
    expect(report.comparisons, isEmpty);
  });
}
