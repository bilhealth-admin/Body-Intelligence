import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_intelligence_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const composer = DashboardIntelligenceComposer();
  final now = DateTime(2026, 7, 29, 12);
  final todayKey = dayKeyFor(now);

  DashboardIntelligenceInput input({
    List<DashboardDecisionMemoryInput> memories = const [],
  }) {
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
        DashboardWeightInput(
          at: now.subtract(const Duration(days: 1)),
          kg: 94.3,
          measurementContext: 'sameConditions',
          dayKey: dayKeyFor(now.subtract(const Duration(days: 1))),
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
      memories: memories,
      skippedWeightToday: false,
    );
  }

  test('composes deterministic dashboard totals and engine outputs', () {
    final first = composer.compose(input());
    final second = composer.compose(input());

    expect(first.calories, 500);
    expect(first.protein, 30);
    expect(first.fats, 18);
    expect(first.waterMl, 750);
    expect(first.currentWeightKg, 94);
    expect(first.fiberEvidence.total, 8);
    expect(first.bestAction.type, second.bestAction.type);
    expect(first.effectiveTargets.calories, second.effectiveTargets.calories);
    expect(first.progress.weeklyDirectionKg, second.progress.weeklyDirectionKg);
    expect(first.calorieByDay[DateTime(2026, 7, 29)], 500);
  });

  test('preserves low-helpfulness suppression policy', () {
    final result = composer.compose(
      input(
        memories: const [
          DashboardDecisionMemoryInput(
            recommendationKey: 'protein',
            helpfulness: 1,
          ),
          DashboardDecisionMemoryInput(
            recommendationKey: 'protein',
            helpfulness: 2,
          ),
        ],
      ),
    );

    expect(result.bestAction.type, isNot(BestActionType.protein));
  });
}
