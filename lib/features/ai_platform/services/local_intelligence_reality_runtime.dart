import '../adapters/local_intelligence_repository_adapter.dart';
import '../domain/adaptive_metabolic_forecast_policy.dart';
import '../domain/ai_evidence.dart';
import '../domain/ai_safety.dart';
import '../domain/ai_safety_policy.dart';
import '../domain/automated_health_insight_summary.dart';
import '../domain/body_twin_consistency_result.dart';
import '../domain/body_twin_freshness_result.dart';
import '../domain/body_twin_observation.dart';
import '../domain/local_intelligence_runtime.dart';
import '../domain/one_best_action.dart';
import '../domain/one_best_action_policy.dart';
import '../domain/proprietary_bil_intelligence.dart';
import '../domain/scientific_validation.dart';
import '../domain/tissue_water_noise_policy.dart';
import '../domain/truth_decision_candidate.dart';
import '../domain/truth_proposition.dart';
import '../domain/truth_rule.dart';
import '../domain/truth_signal.dart';
import 'adaptive_metabolic_forecast_engine.dart';
import 'ai_coach_engine.dart';
import 'ai_context_engine.dart';
import 'ai_safety_engine.dart';
import 'automated_health_insight_engine.dart';
import 'bil_intelligence_integration_engine.dart';
import 'body_twin_engine.dart';
import 'one_best_action_engine.dart';
import 'physiological_reality_model.dart';
import 'proprietary_bil_intelligence_engine.dart';
import 'scientific_validation_engine.dart';
import 'tissue_water_noise_engine.dart';
import 'truth_explain_foundation.dart';

/// Offline-first production orchestrator that derives every downstream engine
/// input from the local timeline and executes the closed AI Platform engines.
final class BilLocalIntelligenceRealityRuntime {
  const BilLocalIntelligenceRealityRuntime({required this.adapter});
  final LocalIntelligenceRepositoryAdapter adapter;

  Future<ProductIntelligenceOutput> run({required DateTime asOf}) async {
    final timeline = await adapter.load(asOf: asOf);
    final physiology = const PhysiologicalRealityModel();
    final tdee = physiology.adaptiveTdee(timeline);
    final estimate = physiology.analyze(timeline, tdeeKcal: tdee);
    final observations = <BodyTwinObservation>[
      for (final day in timeline.weightedDays)
        BodyTwinObservation(
          metricKey: 'weight',
          value: day.weightKg!,
          unit: 'kg',
          observedAt: day.day,
          source: 'local-weight',
        ),
      if (timeline.waistCm != null)
        BodyTwinObservation(
          metricKey: 'waist',
          value: timeline.waistCm!,
          unit: 'cm',
          observedAt: asOf,
          source: 'local-profile',
        ),
      if (timeline.neckCm != null)
        BodyTwinObservation(
          metricKey: 'neck',
          value: timeline.neckCm!,
          unit: 'cm',
          observedAt: asOf,
          source: 'local-profile',
        ),
    ];
    final body = const BodyTwinEngine().build(
      asOf: asOf,
      observations: observations,
      freshnessPolicy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: const {
          'weight': Duration(days: 14),
          'waist': Duration(days: 365),
          'neck': Duration(days: 365),
        },
      ),
      consistencyPolicy: BodyTwinConsistencyPolicy(
        rulesByMetric: {
          'weight': BodyTwinMetricConsistencyRule(
            expectedUnit: 'kg',
            minimum: 20,
            maximum: 400,
          ),
          'waist': BodyTwinMetricConsistencyRule(
            expectedUnit: 'cm',
            minimum: 30,
            maximum: 250,
          ),
          'neck': BodyTwinMetricConsistencyRule(
            expectedUnit: 'cm',
            minimum: 15,
            maximum: 100,
          ),
        },
      ),
      requiredMetricKeys: const ['weight'],
    );
    final coverage =
        timeline.days
            .where(
              (d) => d.weightKg != null || d.caloriesKcal > 0 || d.waterMl > 0,
            )
            .length /
        timeline.days.length;
    final truth = const TruthExplainFoundation().evaluate<bool, String>(
      proposition: TruthProposition<bool>(
        key: 'local.reality.ready',
        description: 'Local evidence supports runtime execution.',
      ),
      context: coverage >= 0.2 && timeline.weightedDays.length >= 2,
      rules: <TruthRule<bool>>[
        TruthRule<bool>(
          key: 'local.reality.coverage',
          propositionKey: 'local.reality.ready',
          direction: TruthSignalDirection.supports,
          strength: 1,
          reliability: coverage,
          matches: (v) => v,
          evidence: (_) => AiEvidence(
            key: 'local.timeline',
            description: 'Bounded local timeline.',
            source: 'local-intelligence-adapter',
          ),
        ),
      ],
      supportedCandidate: TruthDecisionCandidate<String>(
        value: 'proceed',
        label: 'Proceed',
        summary: 'Local evidence is sufficient.',
        reasonWhenNotChosen: 'Evidence insufficient.',
      ),
      contradictedCandidate: TruthDecisionCandidate<String>(
        value: 'abstain',
        label: 'Abstain',
        summary: 'Local evidence is insufficient.',
        reasonWhenNotChosen: 'Evidence sufficient.',
      ),
    );
    final context = const AiContextEngine().build<String>(
      asOf: asOf,
      truthResult: truth,
      bodyTwinResult: body,
      decisionHistory: timeline.decisionHistory,
      requiredContextKeys: const [
        AiContextEngine.truthDecisionKey,
        AiContextEngine.bodySnapshotKey,
        AiContextEngine.bodyTrendsKey,
      ],
    );
    final energyDays = timeline.days.where((d) => d.caloriesKcal > 0).toList();
    final averageIntake = energyDays.isEmpty
        ? null
        : energyDays.fold<double>(0, (s, d) => s + d.caloriesKcal) /
              energyDays.length;
    final balance = averageIntake == null ? null : averageIntake - tdee;
    final tissue = balance == null ? null : balance / 7700;
    final noise = const TissueWaterNoiseEngine().analyze<String>(
      contextResult: context,
      policy: const TissueWaterNoisePolicy(),
      supportedTissueChangeKg: tissue,
      tissueEvidenceIds: balance == null
          ? const []
          : const ['local-energy-balance'],
      waterSignalEvidenceIds: _waterEvidence(timeline),
      evidenceConfidence: estimate.confidence,
    );
    final forecast = const AdaptiveMetabolicForecastEngine().forecast<String>(
      contextResult: context,
      noiseResult: noise,
      policy: const AdaptiveMetabolicForecastPolicy(
        horizons: [Duration(days: 7), Duration(days: 14)],
      ),
      supportedDailyEnergyBalanceKcal: balance,
      energyEvidenceConfidence: estimate.confidence,
      energyEvidenceIds: balance == null
          ? const []
          : const ['local-energy-balance'],
      assumptionIds: const ['kcal-per-kg-7700', 'local-intake-completeness'],
    );
    final candidates = _candidates(timeline, estimate);
    final action = const OneBestActionEngine().select<String>(
      contextResult: context,
      forecastResult: forecast,
      candidates: candidates,
      policy: const OneBestActionPolicy(
        minimumConfidence: 0.45,
        minimumScore: 0.2,
        maximumCandidates: 5,
      ),
    );
    final safety = const AiSafetyEngine().evaluate(
      actionResult: action,
      policy: AiSafetyPolicy(
        rules: [
          AiSafetyRule(
            id: 'no-aggressive-deficit',
            description: 'Block aggressive deficit escalation.',
            severity: AiSafetySeverity.blocking,
            matches: (c) => c.id == 'deepen-deficit',
          ),
          AiSafetyRule(
            id: 'evidence-required',
            description: 'Block actions without evidence.',
            severity: AiSafetySeverity.blocking,
            matches: (c) => c.evidenceIds.isEmpty,
          ),
        ],
      ),
    );
    final insight = const AutomatedHealthInsightEngine().summarize(
      generatedAt: asOf,
      safetyApproved: safety.canProceed,
      evidence: _insights(timeline, estimate, asOf),
      uncertaintyNotes: [
        if (timeline.decisionHistory.isEmpty)
          'No prior Decision Memory evidence is available.',
      ],
    );
    final coach = const AiCoachEngine().coach(
      generatedAt: asOf,
      safetyResult: safety,
      insightSummary: insight,
    );
    final proprietary = const ProprietaryBilIntelligenceEngine().synthesize(
      ProprietaryBilIntelligenceRequest(
        generatedAt: asOf,
        signals: [
          BilIntelligenceSignal(
            id: 'physiology',
            kind: BilIntelligenceSignalKind.factualState,
            statement:
                'Physiology model confidence is ${estimate.confidence.toStringAsFixed(2)}.',
            confidence: estimate.confidence,
            evidenceIds: const ['local-physiology'],
          ),
          BilIntelligenceSignal(
            id: 'action',
            kind: BilIntelligenceSignalKind.action,
            statement: safety.acceptedAction?.title ?? 'No safe action.',
            confidence: safety.canProceed
                ? (safety.acceptedAction?.confidence ?? 0)
                : 0,
            evidenceIds: safety.acceptedAction?.evidenceIds ?? const [],
          ),
        ],
        requiredSignalIds: const ['physiology'],
      ),
    );
    final scientific = const ScientificValidationEngine().validate(
      ScientificValidationRequest(
        generatedAt: asOf,
        sourceSummary: proprietary.summary,
        claims: [
          ScientificClaim(
            id: 'local-runtime',
            statement:
                'The decision was derived from bounded local evidence and closed deterministic engines.',
            strength: ScientificClaimStrength.supportedInference,
            confidence: estimate.confidence,
            evidenceIds: const ['local-physiology'],
            assumptions: const ['local logging completeness'],
          ),
        ],
        availableEvidenceIds: const ['local-physiology'],
      ),
    );
    final brain = const BilIntelligenceIntegrationEngine().integrate<String>(
      generatedAt: asOf,
      contextResult: context,
      bodyTwinResult: body,
      decisionHistory: timeline.decisionHistory,
      forecastResult: forecast,
      tissueWaterAnalysis: noise.analysis,
      actionResult: action,
      safetyResult: safety,
      coachResponse: coach,
      healthInsight: insight,
      proprietaryResult: proprietary,
      scientificResult: scientific,
    );
    return ProductIntelligenceOutput(
      brainResult: brain,
      noiseEstimate: estimate,
      forecast: const [],
      adaptiveTdeeKcal: tdee,
      plateauRisk: forecast.canProceed ? 0.35 : 1,
      primaryMessage: coach.message,
      explanation: [...estimate.explanations, ...brain.explanation],
    );
  }

  static List<String> _waterEvidence(LocalIntelligenceTimeline t) => [
    if (t.days.any((d) => d.sodiumMg > 0)) 'local-sodium',
    if (t.days.any((d) => d.potassiumMg > 0)) 'local-potassium',
    if (t.days.any((d) => d.carbsG > 0)) 'local-carbohydrates',
    if (t.days.any((d) => d.waterMl > 0)) 'local-water',
  ];
  static List<OneBestActionCandidate> _candidates(
    LocalIntelligenceTimeline t,
    PhysiologicalNoiseEstimate e,
  ) => [
    OneBestActionCandidate(
      id: 'continue-plan',
      title: 'Continue the current plan',
      rationale:
          'The local physiological trend does not justify an aggressive change.',
      expectedBenefit: 0.7,
      confidence: e.confidence,
      burden: 0.05,
      safetyEligible: true,
      evidenceIds: const ['local-physiology'],
    ),
    if (t.days.where((d) => d.sleepHours != null).isNotEmpty)
      OneBestActionCandidate(
        id: 'protect-sleep',
        title: 'Protect sleep consistency',
        rationale:
            'Recent sleep context is available and can improve recovery confidence.',
        expectedBenefit: 0.75,
        confidence: 0.7,
        burden: 0.15,
        safetyEligible: true,
        evidenceIds: const ['local-sleep'],
      ),
    if (t.days.where((d) => d.steps != null).isNotEmpty)
      OneBestActionCandidate(
        id: 'maintain-activity',
        title: 'Maintain activity consistency',
        rationale:
            'Recent activity evidence supports preserving the current movement baseline.',
        expectedBenefit: 0.65,
        confidence: 0.7,
        burden: 0.1,
        safetyEligible: true,
        evidenceIds: const ['local-activity'],
      ),
  ];
  static List<HealthInsightEvidence> _insights(
    LocalIntelligenceTimeline t,
    PhysiologicalNoiseEstimate e,
    DateTime asOf,
  ) => [
    HealthInsightEvidence(
      key: 'physiology',
      statement: e.explanations.join(' '),
      provenance: 'PhysiologicalRealityModel',
      observedAt: asOf,
      confidence: e.confidence,
    ),
    if (t.decisionHistory.isNotEmpty)
      HealthInsightEvidence(
        key: 'memory',
        statement: 'Prior local decisions are included in current context.',
        provenance: 'DecisionMemory',
        observedAt: t.decisionHistory.first.record.createdAt,
        confidence: t.decisionHistory.first.record.confidence,
      ),
  ];
}
