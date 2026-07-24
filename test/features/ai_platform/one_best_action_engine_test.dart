import 'package:body_intelligence_log/features/ai_platform/domain/adaptive_metabolic_forecast.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_context.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/one_best_action.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/one_best_action_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_explain_foundation_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/one_best_action_engine.dart';
import 'package:flutter_test/flutter_test.dart';

AiContextEngineResult<String> acceptedContext() {
  return AiContextEngineResult<String>(
    context: AiContext<String>(
      asOf: DateTime.utc(2026, 7, 24),
      truthStatus: TruthExplainFoundationStatus.action,
      truthDecision: 'supported',
      bodySnapshot: null,
      bodyTrends: null,
      decisionHistory: const [],
      missingContextKeys: const [],
      provenance: [
        AiContextProvenance(
          contextKey: 'truth',
          source: AiContextSource.truthExplain,
          evidenceIds: const ['truth:e1'],
        ),
      ],
    ),
    integrityIssues: const [],
    upstreamRejected: false,
  );
}

AdaptiveMetabolicForecastResult acceptedForecast() {
  return AdaptiveMetabolicForecastResult(
    forecast: AdaptiveMetabolicForecast(
      status: AdaptiveMetabolicForecastStatus.accepted,
      asOf: DateTime.utc(2026, 7, 24),
      points: const [
        AdaptiveMetabolicForecastPoint(
          horizon: Duration(days: 7),
          projectedTissueChangeKg: -0.4,
          projectedScaleChangeKg: -0.2,
          confidence: 0.8,
        ),
      ],
      assumptionIds: const ['energy-balance'],
      evidenceIds: const ['forecast:e1'],
      uncertaintyReasons: const [],
    ),
    integrityIssues: const [],
  );
}

const policy = OneBestActionPolicy(
  minimumConfidence: 0.5,
  minimumScore: 0.1,
  maximumCandidates: 3,
);

void main() {
  test('selects highest deterministic eligible action', () {
    final result = const OneBestActionEngine().select<String>(
      contextResult: acceptedContext(),
      forecastResult: acceptedForecast(),
      policy: policy,
      candidates: [
        OneBestActionCandidate(
          id: 'walk',
          title: 'Walk',
          rationale: 'Supports the accepted forecast.',
          expectedBenefit: 0.7,
          confidence: 0.8,
          burden: 0.2,
          safetyEligible: true,
          evidenceIds: const ['action:walk'],
        ),
        OneBestActionCandidate(
          id: 'sleep',
          title: 'Sleep routine',
          rationale: 'Supports recovery.',
          expectedBenefit: 0.5,
          confidence: 0.7,
          burden: 0.1,
          safetyEligible: true,
          evidenceIds: const ['action:sleep'],
        ),
      ],
    );

    expect(result.canProceed, isTrue);
    expect(result.selected?.id, 'walk');
    expect(result.rankedCandidates.map((entry) => entry.rank), [1, 2]);
  });

  test('abstains when no candidate crosses caller policy', () {
    final result = const OneBestActionEngine().select<String>(
      contextResult: acceptedContext(),
      forecastResult: acceptedForecast(),
      policy: policy,
      candidates: [
        OneBestActionCandidate(
          id: 'unsafe',
          title: 'Unsafe',
          rationale: 'Must remain excluded.',
          expectedBenefit: 1,
          confidence: 1,
          burden: 0,
          safetyEligible: false,
          evidenceIds: const ['action:unsafe'],
        ),
      ],
    );

    expect(result.status, OneBestActionStatus.abstained);
    expect(result.selected, isNull);
  });
}
