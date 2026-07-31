import 'data_honesty_engine.dart';
import 'one_best_action_engine.dart';
import 'recovery_engine.dart';
import 'what_changed_engine.dart';

enum DailyReturnState { empty, partial, complete, gentleReturn, rebuilding }

class DailyReturnReport {
  const DailyReturnReport({
    required this.state,
    required this.hasWeight,
    required this.hasMeals,
    required this.hasWater,
    required this.bestAction,
    required this.changed,
    required this.honesty,
    required this.daysAway,
  });

  final DailyReturnState state;
  final bool hasWeight;
  final bool hasMeals;
  final bool hasWater;
  final BestAction bestAction;
  final WhatChangedReport changed;
  final DataHonestyReport honesty;
  final int daysAway;

  bool get hasPrimaryAction =>
      bestAction.type != BestActionType.none &&
      bestAction.type != BestActionType.holdPlan;
}

class DailyReturnEngine {
  const DailyReturnEngine._();

  static DailyReturnReport compose({
    required bool hasWeight,
    required bool hasMeals,
    required bool hasWater,
    required BestAction bestAction,
    required WhatChangedReport changed,
    required DataHonestyReport honesty,
    required RecoveryReport recovery,
  }) {
    final state = switch (recovery.state) {
      RecoveryState.rebuilding => DailyReturnState.rebuilding,
      RecoveryState.gentleReturn when recovery.daysAway >= 4 =>
        DailyReturnState.gentleReturn,
      _ when !hasWeight && !hasMeals && !hasWater => DailyReturnState.empty,
      _
          when bestAction.type == BestActionType.none ||
              bestAction.type == BestActionType.holdPlan =>
        DailyReturnState.complete,
      _ => DailyReturnState.partial,
    };
    return DailyReturnReport(
      state: state,
      hasWeight: hasWeight,
      hasMeals: hasMeals,
      hasWater: hasWater,
      bestAction: bestAction,
      changed: changed,
      honesty: honesty,
      daysAway: recovery.daysAway,
    );
  }
}
