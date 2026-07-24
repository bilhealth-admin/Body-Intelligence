import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_context.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_consistency_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_engine_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_explain_foundation_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_history.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_outcome_transition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_context_engine.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_engine.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_explain_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds accepted bounded context from accepted local engines', () {
    final asOf = DateTime.utc(2026, 7, 24, 12);
    final result = const AiContextEngine().build<String>(
      asOf: asOf,
      truthResult: _truthAction(),
      bodyTwinResult: _body(asOf),
      decisionHistory: <DecisionMemoryHistory>[_history(asOf)],
    );

    expect(result.status, AiContextEngineStatus.accepted);
    expect(result.canProceed, isTrue);
    expect(result.acceptedContext?.truthDecision, 'recover');
    expect(result.acceptedContext?.bodySnapshot, isNotNull);
    expect(result.acceptedContext?.decisionHistory, hasLength(1));
    expect(result.acceptedContext?.provenance, hasLength(4));
  });

  test('preserves missing context and withholds accepted context', () {
    final asOf = DateTime.utc(2026, 7, 24, 12);
    final result = const AiContextEngine().build<String>(
      asOf: asOf,
      truthResult: _truthAction(),
      bodyTwinResult: _body(asOf),
      decisionHistory: const <DecisionMemoryHistory>[],
    );

    expect(result.status, AiContextEngineStatus.incomplete);
    expect(result.canProceed, isFalse);
    expect(result.context.missingContextKeys, contains('decision.memory'));
    expect(result.acceptedContext, isNull);
  });
}

TruthExplainFoundationResult<String> _truthAction() {
  final proposition = TruthProposition<bool>(
    key: 'recovery.ready',
    description: 'Recovery is locally supported.',
  );
  return const TruthExplainFoundation().evaluate<bool, String>(
    proposition: proposition,
    context: true,
    rules: <TruthRule<bool>>[
      TruthRule<bool>(
        key: 'recovery.supported',
        propositionKey: 'recovery.ready',
        direction: TruthSignalDirection.supports,
        strength: 1,
        reliability: 1,
        matches: _alwaysTrue,
        evidence: _evidence,
      ),
    ],
    supportedCandidate: TruthDecisionCandidate<String>(
      value: 'recover',
      label: 'Recover',
      summary: 'Prioritize recovery.',
      reasonWhenNotChosen: 'Not supported.',
    ),
    contradictedCandidate: TruthDecisionCandidate<String>(
      value: 'continue',
      label: 'Continue',
      summary: 'Continue.',
      reasonWhenNotChosen: 'Not contradicted.',
    ),
  );
}

bool _alwaysTrue(bool value) => value;
AiEvidence _evidence(bool _) => AiEvidence(
  key: 'recovery.local',
  description: 'Local evidence.',
  source: 'ai_context_engine_test',
);

BodyTwinEngineResult _body(DateTime asOf) => const BodyTwinEngine().build(
  asOf: asOf,
  observations: <BodyTwinObservation>[
    BodyTwinObservation(
      metricKey: 'weight',
      value: 95.1,
      unit: 'kg',
      observedAt: DateTime.utc(2026, 7, 24, 10),
      source: 'manual',
    ),
  ],
  freshnessPolicy: BodyTwinFreshnessPolicy(
    maxAgeByMetric: <String, Duration>{'weight': Duration(hours: 24)},
  ),
  consistencyPolicy: BodyTwinConsistencyPolicy(
    rulesByMetric: <String, BodyTwinMetricConsistencyRule>{
      'weight': BodyTwinMetricConsistencyRule(expectedUnit: 'kg'),
    },
  ),
  requiredMetricKeys: <String>['weight'],
);

DecisionMemoryHistory _history(DateTime asOf) => DecisionMemoryHistory(
  record: DecisionMemoryRecord(
    id: 'decision-1',
    createdAt: asOf.subtract(const Duration(hours: 1)),
    decisionKey: 'recovery',
    selectedAction: 'recover',
    rationale: 'Local evidence.',
    confidence: 0.9,
    evidenceIds: const <String>['recovery.local'],
    outcomeState: 'pending',
  ),
  currentState: DecisionOutcomeState.pending,
  transitions: const <DecisionOutcomeTransition>[],
);
