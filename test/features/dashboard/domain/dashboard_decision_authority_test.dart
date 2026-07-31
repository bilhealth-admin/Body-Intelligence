import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_decision_authority.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_intelligence_composer.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingDecisionAuthority implements DashboardDecisionAuthority {
  var calls = 0;
  bool? weighedToday;
  bool? loggingComplete;
  double? protein;
  int? proteinTarget;
  int? waterMl;
  int? waterTarget;
  int? trackedDays;
  Set<BestActionType>? suppressedTypes;

  @override
  BestAction choose({
    required bool weighedToday,
    required bool loggingComplete,
    required double protein,
    required int proteinTarget,
    required int waterMl,
    required int waterTarget,
    required int trackedDays,
    Set<BestActionType> suppressedTypes = const {},
  }) {
    calls += 1;
    this.weighedToday = weighedToday;
    this.loggingComplete = loggingComplete;
    this.protein = protein;
    this.proteinTarget = proteinTarget;
    this.waterMl = waterMl;
    this.waterTarget = waterTarget;
    this.trackedDays = trackedDays;
    this.suppressedTypes = suppressedTypes;
    return const BestAction(
      type: BestActionType.holdPlan,
      title: 'Authority result',
      reason: 'Delegated through the dashboard boundary.',
      evidence: ['recorded'],
    );
  }
}

void main() {
  final now = DateTime(2026, 7, 29, 12);
  final todayKey = dayKeyFor(now);

  DashboardIntelligenceInput input() {
    final meal = DashboardMealInput(
      at: now,
      dayKey: todayKey,
      items: [
        DashboardMealItemInput(
          calories: 500,
          protein: 30,
          fats: 18,
          sodium: 600,
          fiber: 8,
          nutrientEvidenceMask: NutrientEvidenceMask.fromValues(fiber: 8),
        ),
      ],
    );

    return DashboardIntelligenceInput(
      now: now,
      profile: const DashboardProfileInput(
        age: 36,
        gender: 'male',
        heightCm: 181,
        currentWeightKg: 94,
        targetWeightKg: 85,
        activityLevel: 'sedentary',
        exercises: false,
        neckCm: 43,
        waistCm: 104,
      ),
      weights: [
        DashboardWeightInput(
          at: now,
          kg: 94,
          measurementContext: 'sameConditions',
          dayKey: todayKey,
        ),
      ],
      todayMeals: [meal],
      todayWater: [
        DashboardWaterInput(at: now, dayKey: todayKey, amountMl: 750),
      ],
      allMeals: [meal],
      allWater: [DashboardWaterInput(at: now, dayKey: todayKey, amountMl: 750)],
      insightContexts: const [],
      allContexts: const [],
      memories: const [],
      skippedWeightToday: false,
    );
  }

  test(
    'delegates One Best Action selection through the authority boundary',
    () {
      final authority = _RecordingDecisionAuthority();
      final snapshot = DashboardIntelligenceComposer(
        decisionAuthority: authority,
      ).compose(input());

      expect(authority.calls, 1);
      expect(authority.weighedToday, isTrue);
      expect(authority.loggingComplete, isTrue);
      expect(authority.protein, 30);
      expect(authority.waterMl, 750);
      expect(authority.proteinTarget, greaterThan(0));
      expect(authority.waterTarget, greaterThan(0));
      expect(authority.trackedDays, 1);
      expect(authority.suppressedTypes, isEmpty);
      expect(snapshot.bestAction.title, 'Authority result');
      expect(snapshot.bestAction.type, BestActionType.holdPlan);
    },
  );

  test('legacy authority preserves the existing engine result', () {
    const authority = LegacyDashboardDecisionAuthority();
    final actual = authority.choose(
      weighedToday: true,
      loggingComplete: true,
      protein: 30,
      proteinTarget: 120,
      waterMl: 750,
      waterTarget: 2500,
      trackedDays: 1,
    );
    final expected = OneBestActionEngine.choose(
      weighedToday: true,
      loggingComplete: true,
      protein: 30,
      proteinTarget: 120,
      waterMl: 750,
      waterTarget: 2500,
      trackedDays: 1,
    );

    expect(actual.type, expected.type);
    expect(actual.title, expected.title);
    expect(actual.reason, expected.reason);
    expect(actual.evidence, expected.evidence);
  });
}
