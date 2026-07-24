import 'package:body_intelligence_log/features/ai_platform/domain/adaptive_metabolic_forecast.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_history.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_outcome_transition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/local_intelligence_runtime.dart';
import 'package:body_intelligence_log/features/ai_platform/services/product_intelligence_behavior_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const behavior = ProductIntelligenceBehaviorModel();

  test('maps accepted 7 and 14 day engine forecasts to product output', () {
    final result = AdaptiveMetabolicForecastResult(
      forecast: AdaptiveMetabolicForecast(
        status: AdaptiveMetabolicForecastStatus.accepted,
        asOf: DateTime.utc(2026, 7, 24),
        points: const [
          AdaptiveMetabolicForecastPoint(
            horizon: Duration(days: 7),
            projectedTissueChangeKg: -0.5,
            projectedScaleChangeKg: -0.2,
            confidence: 0.8,
          ),
          AdaptiveMetabolicForecastPoint(
            horizon: Duration(days: 14),
            projectedTissueChangeKg: -1,
            projectedScaleChangeKg: -0.7,
            confidence: 0.8,
          ),
        ],
        assumptionIds: const ['energy-balance'],
        evidenceIds: const ['local-energy-balance'],
        uncertaintyReasons: const [],
      ),
      integrityIssues: const [],
    );

    final points = behavior.productForecast(result: result, latestWeightKg: 95);

    expect(points.map((point) => point.days), [7, 14]);
    expect(points.first.projectedWeightKg, closeTo(94.8, 0.0001));
    expect(points.last.projectedWeightKg, closeTo(94.3, 0.0001));
  });

  test('plateau risk changes with observed slowdown and confidence', () {
    final progressing = _timeline(weights: const [96, 95.6, 95.2, 94.8]);
    final flat = _timeline(weights: const [96, 95.9, 95.9, 95.9]);
    final accepted = _forecast(canProceed: true);

    final low = behavior.plateauRisk(
      timeline: progressing,
      adaptiveTdeeKcal: 2400,
      averageIntakeKcal: 1800,
      forecastResult: accepted,
      physiologyConfidence: 0.9,
    );
    final high = behavior.plateauRisk(
      timeline: flat,
      adaptiveTdeeKcal: 2400,
      averageIntakeKcal: 1800,
      forecastResult: accepted,
      physiologyConfidence: 0.55,
    );

    expect(high, greaterThan(low));
  });

  test('failed Decision Memory lowers repeated action ranking', () {
    final base = _timeline(weights: const [96, 95.8, 95.7, 95.7]);
    final failed = _timeline(
      weights: const [96, 95.8, 95.7, 95.7],
      history: [
        DecisionMemoryHistory(
          record: DecisionMemoryRecord(
            id: 'memory-1',
            createdAt: DateTime.utc(2026, 7, 23),
            decisionKey: 'audit-plateau-inputs',
            selectedAction: 'Audit plateau drivers before changing calories',
            rationale: 'Prior trial failed.',
            confidence: 0.8,
            evidenceIds: const ['local-decision-memory'],
            outcomeState: 'failed',
          ),
          currentState: DecisionOutcomeState.failed,
          transitions: const [],
        ),
      ],
    );
    final estimate = PhysiologicalNoiseEstimate(
      observedScaleChangeKg: -0.3,
      estimatedTissueChangeKg: -0.7,
      waterAndGlycogenNoiseKg: 0.4,
      digestiveMassNoiseKg: 0,
      sodiumDriverKg: 0.2,
      potassiumDriverKg: 0.1,
      carbohydrateDriverKg: 0.1,
      hydrationDriverKg: 0,
      confidence: 0.8,
      explanations: const [],
    );

    final normal = behavior
        .candidates(
          timeline: base,
          estimate: estimate,
          adaptiveTdeeKcal: 2400,
          averageIntakeKcal: 1800,
          plateauRisk: 0.8,
        )
        .firstWhere((candidate) => candidate.id == 'audit-plateau-inputs');
    final penalized = behavior
        .candidates(
          timeline: failed,
          estimate: estimate,
          adaptiveTdeeKcal: 2400,
          averageIntakeKcal: 1800,
          plateauRisk: 0.8,
        )
        .firstWhere((candidate) => candidate.id == 'audit-plateau-inputs');

    expect(penalized.rankingScore, lessThan(normal.rankingScore));
    expect(penalized.evidenceIds, contains('decision-memory:memory-1'));
  });
}

LocalIntelligenceTimeline _timeline({
  required List<double> weights,
  List<DecisionMemoryHistory> history = const [],
}) => LocalIntelligenceTimeline(
  age: 36,
  heightCm: 181,
  gender: 'male',
  activityLevel: 'moderate',
  targetWeightKg: 88,
  days: [
    for (var index = 0; index < weights.length; index++)
      LocalDailyPhysiology(
        day: DateTime.utc(2026, 7, 1 + (index * 7)),
        weightKg: weights[index],
        caloriesKcal: 1800,
        proteinG: 110,
        carbsG: 150,
        fatG: 60,
        sodiumMg: 2800,
        potassiumMg: 2500,
        waterMl: 2500,
        sleepHours: 6,
        steps: 5000,
        contextTypes: const [],
      ),
  ],
  decisionHistory: history,
);

AdaptiveMetabolicForecastResult _forecast({required bool canProceed}) =>
    AdaptiveMetabolicForecastResult(
      forecast: AdaptiveMetabolicForecast(
        status: canProceed
            ? AdaptiveMetabolicForecastStatus.accepted
            : AdaptiveMetabolicForecastStatus.abstained,
        asOf: DateTime.utc(2026, 7, 24),
        points: canProceed
            ? const [
                AdaptiveMetabolicForecastPoint(
                  horizon: Duration(days: 7),
                  projectedTissueChangeKg: -0.5,
                  projectedScaleChangeKg: -0.2,
                  confidence: 0.8,
                ),
              ]
            : const [],
        assumptionIds: canProceed ? const ['energy-balance'] : const [],
        evidenceIds: canProceed ? const ['local-energy-balance'] : const [],
        uncertaintyReasons: const [],
      ),
      integrityIssues: const [],
    );
