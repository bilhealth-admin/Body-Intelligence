import 'package:body_intelligence_log/engine/daily_return_engine.dart';
import 'package:body_intelligence_log/engine/data_honesty_engine.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/engine/recovery_engine.dart';
import 'package:body_intelligence_log/engine/what_changed_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const honesty = DataHonestyReport(
    score: 20,
    reliability: DataReliability.insufficient,
    strengths: [],
    missing: ['More comparable days needed'],
  );
  const changed = WhatChangedReport(
    interpretation: ChangeInterpretation.insufficient,
    summary: 'Another comparable weight is needed.',
    evidence: [],
    alternatives: ['Normal variation remains unknown'],
  );

  DailyReturnReport report({
    bool weight = false,
    bool meals = false,
    bool water = false,
    BestActionType action = BestActionType.weighIn,
    RecoveryState recovery = RecoveryState.current,
    int daysAway = 0,
  }) => DailyReturnEngine.compose(
    hasWeight: weight,
    hasMeals: meals,
    hasWater: water,
    bestAction: BestAction(
      type: action,
      title: action.name,
      reason: 'Deterministic reason',
      evidence: const ['Local evidence'],
    ),
    changed: changed,
    honesty: honesty,
    recovery: RecoveryReport(
      state: recovery,
      daysAway: daysAway,
      title: 'Recovery',
      actions: const [],
    ),
  );

  test('empty current day selects one useful action', () {
    final value = report();
    expect(value.state, DailyReturnState.empty);
    expect(value.hasPrimaryAction, isTrue);
  });

  test('partially recorded day continues the existing best action', () {
    final value = report(weight: true, action: BestActionType.completeLogging);
    expect(value.state, DailyReturnState.partial);
    expect(value.bestAction.type, BestActionType.completeLogging);
  });

  test('covered day honestly allows no action', () {
    final value = report(
      weight: true,
      meals: true,
      water: true,
      action: BestActionType.none,
    );
    expect(value.state, DailyReturnState.complete);
    expect(value.hasPrimaryAction, isFalse);
  });

  test('hold-plan advice does not pressure more logging', () {
    final value = report(
      weight: true,
      meals: true,
      water: true,
      action: BestActionType.holdPlan,
    );
    expect(value.state, DailyReturnState.complete);
    expect(value.hasPrimaryAction, isFalse);
  });

  test('missed days use gentle recovery without backfill', () {
    final value = report(recovery: RecoveryState.gentleReturn, daysAway: 6);
    expect(value.state, DailyReturnState.gentleReturn);
    expect(value.daysAway, 6);
  });

  test('long absence preserves rebuilding state', () {
    expect(
      report(recovery: RecoveryState.rebuilding, daysAway: 20).state,
      DailyReturnState.rebuilding,
    );
  });
}
