import '../domain/adaptive_metabolic_forecast.dart';
import '../domain/ai_coach_response.dart';
import '../domain/ai_context.dart';
import '../domain/ai_safety.dart';
import '../domain/automated_health_insight_summary.dart';
import '../domain/bil_intelligence_integration.dart';
import '../domain/bil_intelligence_integration_policy.dart';
import '../domain/body_twin_engine_result.dart';
import '../domain/decision_memory_history.dart';
import '../domain/one_best_action.dart';
import '../domain/proprietary_bil_intelligence.dart';
import '../domain/scientific_validation.dart';
import '../domain/tissue_water_noise_analysis.dart';

/// Final deterministic integration layer over already-closed AI Platform engines.
///
/// BIL Confidence Fusion uses a weighted harmonic mean so one weak critical
/// engine cannot be hidden by several strong auxiliary engines. Truth
/// reconciliation applies explicit contradiction penalties and hard-gate
/// rejection without recreating any upstream engine logic.
final class BilIntelligenceIntegrationEngine {
  const BilIntelligenceIntegrationEngine();

  UnifiedHealthBrainResult integrate<T>({
    required DateTime generatedAt,
    required AiContextEngineResult<T> contextResult,
    required BodyTwinEngineResult bodyTwinResult,
    required Iterable<DecisionMemoryHistory> decisionHistory,
    required AdaptiveMetabolicForecastResult forecastResult,
    required TissueWaterNoiseAnalysis tissueWaterAnalysis,
    required OneBestActionResult actionResult,
    required AiSafetyResult safetyResult,
    required AiCoachResponse coachResponse,
    required AutomatedHealthInsightSummary healthInsight,
    required ProprietaryBilIntelligenceResult proprietaryResult,
    required ScientificValidationResult scientificResult,
    BilIntelligenceIntegrationPolicy? policy,
  }) {
    final effectivePolicy = policy ?? BilIntelligenceIntegrationPolicy();
    final normalizedAt = generatedAt.toUtc();
    final signals = <BilIntegrationSignal>[
      _signal(
        source: BilIntegrationSource.aiContext,
        confidence: contextResult.canProceed
            ? 1
            : contextResult.status == AiContextEngineStatus.incomplete
            ? 0.45
            : 0,
        accepted: contextResult.canProceed,
        critical: true,
        evidence: contextResult.context.provenance.expand(
          (item) => item.evidenceIds,
        ),
        reasons: <String>[
          ...contextResult.integrityIssues,
          ...contextResult.context.missingContextKeys,
        ],
      ),
      _signal(
        source: BilIntegrationSource.bodyTwin,
        confidence: bodyTwinResult.canProceed
            ? 1
            : bodyTwinResult.status == BodyTwinEngineStatus.incomplete
            ? 0.45
            : 0,
        accepted: bodyTwinResult.canProceed,
        critical: true,
        evidence:
            bodyTwinResult.acceptedSnapshot?.observationsByMetric.keys ??
            const <String>[],
        reasons: bodyTwinResult.integrityIssues,
      ),
      _signal(
        source: BilIntegrationSource.decisionMemory,
        confidence: decisionHistory.isEmpty ? 0.5 : 1,
        accepted: true,
        critical: false,
        evidence: decisionHistory.map((item) => item.record.id),
        reasons: decisionHistory.isEmpty
            ? const <String>['No prior decision history is available.']
            : const <String>[],
      ),
      _signal(
        source: BilIntegrationSource.adaptiveForecast,
        confidence: _forecastConfidence(forecastResult),
        accepted: forecastResult.canProceed,
        critical: false,
        evidence: forecastResult.forecast.evidenceIds,
        reasons: <String>[
          ...forecastResult.integrityIssues,
          ...forecastResult.forecast.uncertaintyReasons,
        ],
      ),
      _signal(
        source: BilIntegrationSource.tissueWater,
        confidence: tissueWaterAnalysis.confidence,
        accepted: tissueWaterAnalysis.canProceed,
        critical: false,
        evidence: tissueWaterAnalysis.evidenceIds,
        reasons: tissueWaterAnalysis.uncertaintyReasons,
      ),
      _signal(
        source: BilIntegrationSource.oneBestAction,
        confidence: actionResult.selected?.confidence ?? 0,
        accepted: actionResult.canProceed,
        critical: true,
        evidence: actionResult.selected?.evidenceIds ?? const <String>[],
        reasons: <String>[
          ...actionResult.reasons,
          ...actionResult.integrityIssues,
        ],
      ),
      _signal(
        source: BilIntegrationSource.safety,
        confidence: safetyResult.canProceed
            ? 1
            : safetyResult.status == AiSafetyStatus.abstained
            ? 0.4
            : 0,
        accepted: safetyResult.canProceed,
        critical: true,
        evidence: safetyResult.issues.map((item) => item.ruleId),
        reasons: safetyResult.reasons,
      ),
      _signal(
        source: BilIntegrationSource.coach,
        confidence: coachResponse.canProceed ? 0.9 : 0.35,
        accepted: coachResponse.canProceed,
        critical: false,
        evidence: coachResponse.evidenceIds,
        reasons: <String>[
          ...coachResponse.uncertaintyNotes,
          ...coachResponse.safetyNotes,
        ],
      ),
      _signal(
        source: BilIntegrationSource.healthInsight,
        confidence: _insightConfidence(healthInsight),
        accepted: !healthInsight.isAbstained && healthInsight.safetyApproved,
        critical: false,
        evidence: healthInsight.evidence.map((item) => item.key),
        reasons: healthInsight.uncertaintyNotes,
      ),
      _signal(
        source: BilIntegrationSource.proprietaryIntelligence,
        confidence: proprietaryResult.canProceed ? 0.9 : 0,
        accepted: proprietaryResult.canProceed,
        critical: true,
        evidence: proprietaryResult.evidenceIds,
        reasons: proprietaryResult.issues,
      ),
      _signal(
        source: BilIntegrationSource.scientificValidation,
        confidence: _scientificConfidence(scientificResult),
        accepted: scientificResult.canProceed,
        critical: true,
        evidence: scientificResult.records.expand((item) => item.evidenceIds),
        reasons: scientificResult.issues,
      ),
    ];

    final conflicts = _reconcile(
      contextResult: contextResult,
      actionResult: actionResult,
      safetyResult: safetyResult,
      coachResponse: coachResponse,
      healthInsight: healthInsight,
      proprietaryResult: proprietaryResult,
      scientificResult: scientificResult,
    );
    return integrateSignals(
      generatedAt: normalizedAt,
      signals: signals,
      candidateAction: safetyResult.acceptedAction,
      reconciliationIssues: conflicts,
      policy: effectivePolicy,
    );
  }

  UnifiedHealthBrainResult integrateSignals({
    required DateTime generatedAt,
    required Iterable<BilIntegrationSignal> signals,
    required OneBestActionCandidate? candidateAction,
    Iterable<String> reconciliationIssues = const <String>[],
    BilIntelligenceIntegrationPolicy? policy,
  }) {
    final effectivePolicy = policy ?? BilIntelligenceIntegrationPolicy();
    final immutableSignals = signals.toList(growable: false);
    if (immutableSignals.isEmpty) {
      throw ArgumentError.value(signals, 'signals', 'must not be empty');
    }
    final conflicts = reconciliationIssues.toSet().toList()..sort();
    final fused = _fuse(immutableSignals, effectivePolicy);
    final adjusted =
        (fused - (conflicts.length * effectivePolicy.conflictPenalty)).clamp(
          0.0,
          1.0,
        );
    final criticalFailures = immutableSignals
        .where((signal) => signal.critical && !signal.accepted)
        .length;
    final rejected =
        criticalFailures > effectivePolicy.maximumCriticalFailures ||
        conflicts.any((item) => item.startsWith('hard:'));
    final accepted =
        !rejected &&
        adjusted >= effectivePolicy.minimumUnifiedConfidence &&
        candidateAction != null;
    final status = rejected
        ? BilIntegrationStatus.rejected
        : accepted
        ? BilIntegrationStatus.accepted
        : BilIntegrationStatus.abstained;
    final evidence = immutableSignals
        .expand((signal) => signal.evidenceIds)
        .toSet();
    final selectedAction = status == BilIntegrationStatus.accepted
        ? candidateAction
        : null;
    final explanation = <String>[
      'BIL Confidence Fusion=${adjusted.toStringAsFixed(4)} using weighted harmonic aggregation.',
      'Critical failures=$criticalFailures; reconciliation issues=${conflicts.length}.',
      if (selectedAction != null)
        'Unified decision=${selectedAction.id}: ${selectedAction.title}.',
      if (status != BilIntegrationStatus.accepted)
        'The Unified Health Brain abstained or rejected instead of hiding uncertainty.',
    ];
    final trace = <BilDecisionTraceEntry>[
      BilDecisionTraceEntry(
        sequence: 1,
        code: 'collect',
        statement:
            'Collected immutable outputs from closed AI Platform engines.',
        evidenceIds: evidence,
      ),
      BilDecisionTraceEntry(
        sequence: 2,
        code: 'reconcile',
        statement: conflicts.isEmpty
            ? 'Cross-engine truth reconciliation found no contradictions.'
            : 'Cross-engine reconciliation exposed ${conflicts.length} issue(s).',
        evidenceIds: evidence,
      ),
      BilDecisionTraceEntry(
        sequence: 3,
        code: 'fuse',
        statement:
            'Applied BIL weighted harmonic confidence fusion with contradiction penalties.',
        evidenceIds: evidence,
      ),
      BilDecisionTraceEntry(
        sequence: 4,
        code: 'gate',
        statement:
            'Applied critical truth, action, safety, proprietary, and scientific gates.',
        evidenceIds: evidence,
      ),
      BilDecisionTraceEntry(
        sequence: 5,
        code: 'decision',
        statement: 'Produced one ${status.name} unified health decision.',
        evidenceIds: evidence,
      ),
    ];

    return UnifiedHealthBrainResult(
      status: status,
      generatedAt: generatedAt,
      confidence: adjusted,
      selectedAction: selectedAction,
      signals: immutableSignals,
      evidenceIds: evidence,
      reconciliationIssues: conflicts,
      explanation: explanation,
      decisionTrace: trace,
    );
  }

  BilIntegrationSignal _signal({
    required BilIntegrationSource source,
    required double confidence,
    required bool accepted,
    required bool critical,
    required Iterable<String> evidence,
    required Iterable<String> reasons,
  }) => BilIntegrationSignal(
    source: source,
    confidence: confidence.clamp(0.0, 1.0),
    accepted: accepted,
    critical: critical,
    evidenceIds: evidence,
    reasons: reasons,
  );

  double _fuse(
    List<BilIntegrationSignal> signals,
    BilIntelligenceIntegrationPolicy policy,
  ) {
    var numerator = 0.0;
    var denominator = 0.0;
    for (final signal in signals) {
      final weight = policy.sourceWeights[signal.source] ?? 1;
      numerator += weight;
      denominator += weight / signal.confidence.clamp(0.01, 1.0);
    }
    return denominator == 0 ? 0 : numerator / denominator;
  }

  List<String> _reconcile<T>({
    required AiContextEngineResult<T> contextResult,
    required OneBestActionResult actionResult,
    required AiSafetyResult safetyResult,
    required AiCoachResponse coachResponse,
    required AutomatedHealthInsightSummary healthInsight,
    required ProprietaryBilIntelligenceResult proprietaryResult,
    required ScientificValidationResult scientificResult,
  }) {
    final issues = <String>[];
    if (actionResult.canProceed && !contextResult.canProceed) {
      issues.add('hard: action accepted without accepted AI Context.');
    }
    if (actionResult.canProceed && !safetyResult.canProceed) {
      issues.add('hard: action accepted but AI Safety did not accept it.');
    }
    if (coachResponse.canProceed &&
        coachResponse.actionId != actionResult.selected?.id) {
      issues.add('hard: AI Coach action differs from One Best Action.');
    }
    if (!healthInsight.safetyApproved && !healthInsight.isAbstained) {
      issues.add('hard: health insight was emitted without safety approval.');
    }
    if (proprietaryResult.canProceed && !scientificResult.canProceed) {
      issues.add('hard: proprietary synthesis lacks scientific validation.');
    }
    if (safetyResult.acceptedAction?.id != null &&
        safetyResult.acceptedAction?.id != actionResult.selected?.id) {
      issues.add('hard: safety accepted a different action identity.');
    }
    return issues..sort();
  }

  double _forecastConfidence(AdaptiveMetabolicForecastResult result) {
    if (!result.canProceed || result.forecast.points.isEmpty) {
      return 0;
    }
    return result.forecast.points
            .map((point) => point.confidence)
            .reduce((a, b) => a + b) /
        result.forecast.points.length;
  }

  double _insightConfidence(AutomatedHealthInsightSummary summary) {
    if (summary.isAbstained ||
        !summary.safetyApproved ||
        summary.evidence.isEmpty) {
      return 0;
    }
    return summary.evidence
            .map((item) => item.confidence)
            .reduce((a, b) => a + b) /
        summary.evidence.length;
  }

  double _scientificConfidence(ScientificValidationResult result) {
    if (!result.canProceed || result.records.isEmpty) {
      return 0;
    }
    return result.records
            .map((item) => item.confidence)
            .reduce((a, b) => a + b) /
        result.records.length;
  }
}
