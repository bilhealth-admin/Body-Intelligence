import 'package:body_intelligence_log/engine/intelligence_engine.dart';
import 'package:body_intelligence_log/engine/one_best_action_engine.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_decision_authority.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_trusted_truth_decision_adapter.dart';
import 'package:body_intelligence_log/features/dashboard/presentation/dashboard_intelligence_localizer.dart';
import 'package:body_intelligence_log/features/exercise_calorie_controls/domain/exercise_calorie_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Arabic incomplete insight cannot become a claim of aligned targets',
    () {
      final report = IntelligenceEngine.evaluate(
        calorieTarget: 2000,
        proteinTarget: 120,
        waterTarget: 2500,
        calories: 2000,
        protein: null,
        waterMl: 2500,
        chronologicalWeights: const [],
        goalWeight: 82,
        trackedDays: 14,
      );
      expect(
        const DashboardIntelligenceLocalizer(
          arabic: true,
        ).insightTitle(report.insights.single.title),
        'الأدلة الغذائية غير مكتملة',
      );
    },
  );

  test(
    'Arabic missing-evidence abstention cannot become a covered-day claim',
    () {
      final action = const TrustedDashboardDecisionAuthority().choose(
        weighedToday: true,
        loggingComplete: true,
        protein: null,
        proteinTarget: 120,
        waterMl: 2500,
        waterTarget: 2500,
        trackedDays: 14,
      );
      const localizer = DashboardIntelligenceLocalizer(arabic: true);
      expect(
        action.abstentionReason,
        BestActionAbstentionReason.incompleteOrInvalidEvidence,
      );
      expect(localizer.bestActionTitle(action), 'لا تتوفر توصية موثوقة بعد');
      expect(
        localizer.bestActionReason(action),
        'لم يقدم BIL توصية لأن البيانات المتاحة غير مكتملة أو غير صالحة.',
      );
    },
  );

  test('missing protein does not become a gap or an aligned-day claim', () {
    final report = IntelligenceEngine.evaluate(
      calorieTarget: 2000,
      proteinTarget: 120,
      waterTarget: 2500,
      calories: 2000,
      protein: null,
      waterMl: 2500,
      chronologicalWeights: const [],
      goalWeight: 82,
      trackedDays: 14,
    );
    expect(report.score, isNull);
    expect(report.scoreConfidence, InsightConfidence.insufficient);
    expect(report.insights.map((insight) => insight.title), [
      'Nutrition evidence is incomplete',
    ]);
    final action = const TrustedDashboardDecisionAuthority().choose(
      weighedToday: true,
      loggingComplete: true,
      protein: null,
      proteinTarget: 120,
      waterMl: 2500,
      waterTarget: 2500,
      trackedDays: 14,
    );
    expect(action.type, BestActionType.none);
    expect(action.title, 'No trusted action is available yet');
    expect(action.reason, contains('incomplete'));
    expect(action.evidence.join(' '), isNot(contains('records are present')));
  });

  test('Truth adapter rejects a protein claim without protein evidence', () {
    const inventedGap = BestAction(
      type: BestActionType.protein,
      title: 'Add about 120 g protein',
      reason: 'Protein is below target.',
      evidence: ['0 g logged', '120 g target'],
    );
    final result = const DashboardTrustedTruthDecisionAdapter().evaluate(
      const DashboardTruthDecisionContext(
        weighedToday: true,
        loggingComplete: true,
        protein: null,
        proteinTarget: 120,
        waterMl: 2500,
        waterTarget: 2500,
        trackedDays: 14,
        proposedAction: inventedGap,
      ),
    );
    expect(result.action, isNull);
    expect(result.isSafeAbstention, isTrue);
  });

  for (final includeExercise in [false, true]) {
    test(
      'unknown intake keeps remaining unknown with exercise=$includeExercise',
      () {
        final day = DateTime(2026, 10, 6);
        final preferences = ExerciseCaloriePreferences(
          includeInRemainingGoal: includeExercise,
          adjustMacroGoals: false,
        );
        ExerciseCalorieResult calculate(double? intake) =>
            ExerciseCaloriePolicy.calculate(
              preferences: preferences,
              day: day,
              baseCalorieGoal: 2100,
              consumedCalories: intake,
              baseProteinGoal: 140,
              baseCarbohydrateGoal: 240,
              baseFatGoal: 65,
              energy: AuthoritativeExerciseEnergy(
                kcal: 321,
                observedAt: day,
                source: 'isolated_verified_health_fixture',
                confidence: 1,
              ),
            );
        final unknown = calculate(null);
        final knownZero = calculate(0);
        expect(unknown.remainingCalories, isNull);
        expect(unknown.baseCalorieGoal, 2100);
        expect(unknown.effectiveCalorieGoal, includeExercise ? 2421 : 2100);
        expect(knownZero.remainingCalories, unknown.effectiveCalorieGoal);
        expect(unknown.proteinGoal, 140);
        expect(unknown.carbohydrateGoal, 240);
        expect(unknown.fatGoal, 65);
        expect(unknown.availability, knownZero.availability);
        expect(unknown.appliedExerciseKcal, knownZero.appliedExerciseKcal);
      },
    );
  }
}
