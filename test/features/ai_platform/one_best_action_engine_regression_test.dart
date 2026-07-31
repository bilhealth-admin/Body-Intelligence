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
  test('ranking is stable independent of candidate insertion order', () {
    OneBestActionCandidate candidate(String id) => OneBestActionCandidate(
      id: id,
      title: id,
      rationale: 'supported',
      expectedBenefit: 0.6,
      confidence: 0.8,
      burden: 0.2,
      safetyEligible: true,
      evidenceIds: ['e:$id'],
    );

    final engine = const OneBestActionEngine();
    final first = engine.select<String>(
      contextResult: acceptedContext(),
      forecastResult: acceptedForecast(),
      policy: policy,
      candidates: [candidate('b'), candidate('a')],
    );
    final second = engine.select<String>(
      contextResult: acceptedContext(),
      forecastResult: acceptedForecast(),
      policy: policy,
      candidates: [candidate('a'), candidate('b')],
    );

    expect(first.selected?.id, 'a');
    expect(second.selected?.id, 'a');
  });

  test('rejects when accepted upstream boundaries are unavailable', () {
    final context = AiContextEngineResult<String>(
      context: AiContext<String>(
        asOf: DateTime.utc(2026, 7, 24),
        truthStatus: TruthExplainFoundationStatus.rejected,
        truthDecision: null,
        bodySnapshot: null,
        bodyTrends: null,
        decisionHistory: const [],
        missingContextKeys: const ['truth'],
        provenance: const [],
      ),
      integrityIssues: const [],
      upstreamRejected: true,
    );
    final result = const OneBestActionEngine().select<String>(
      contextResult: context,
      forecastResult: acceptedForecast(),
      policy: policy,
      candidates: const [],
    );

    expect(result.status, OneBestActionStatus.rejected);
    expect(result.canProceed, isFalse);
  });
}
