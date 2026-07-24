import 'dart:math' as math;

import '../adapters/local_intelligence_repository_adapter.dart';
import '../domain/bil_intelligence_integration.dart';
import '../domain/local_intelligence_runtime.dart';
import '../domain/one_best_action.dart';
import 'bil_intelligence_integration_engine.dart';
import 'physiological_reality_model.dart';

/// Complete offline runtime entry point. The caller supplies only the local
/// database-backed adapter and a timestamp; engine inputs and action candidates
/// are derived internally from actual local history.
final class BilLocalIntelligenceRuntime {
  const BilLocalIntelligenceRuntime({
    required this.adapter,
    this.physiology = const PhysiologicalRealityModel(),
    this.integration = const BilIntelligenceIntegrationEngine(),
  });

  final LocalIntelligenceRepositoryAdapter adapter;
  final PhysiologicalRealityModel physiology;
  final BilIntelligenceIntegrationEngine integration;

  Future<ProductIntelligenceOutput> run({required DateTime asOf}) async {
    final timeline = await adapter.load(asOf: asOf);
    final tdee = physiology.adaptiveTdee(timeline);
    final noise = physiology.analyze(timeline, tdeeKcal: tdee);
    final forecast = _forecast(timeline, tdee, noise);
    final plateauRisk = _plateauRisk(timeline, forecast, noise);
    final candidates = _candidates(timeline, noise, forecast, plateauRisk);
    final selected = candidates.isEmpty ? null : candidates.first;
    final coverage = _coverage(timeline);
    final signals = <BilIntegrationSignal>[
      _signal(
        BilIntegrationSource.aiContext,
        coverage,
        coverage >= 0.45,
        true,
        'local-context',
      ),
      _signal(
        BilIntegrationSource.bodyTwin,
        noise.confidence,
        timeline.weightedDays.length >= 2,
        true,
        'weight-history',
      ),
      _signal(
        BilIntegrationSource.decisionMemory,
        0.7,
        true,
        false,
        'local-memory',
      ),
      _signal(
        BilIntegrationSource.adaptiveForecast,
        forecast.last.confidence,
        forecast.last.confidence >= 0.45,
        false,
        'forecast-14d',
      ),
      _signal(
        BilIntegrationSource.tissueWater,
        noise.confidence,
        noise.confidence >= 0.45,
        false,
        'physiology-noise',
      ),
      _signal(
        BilIntegrationSource.oneBestAction,
        selected?.confidence ?? 0,
        selected != null,
        true,
        selected?.id ?? 'no-action',
      ),
      _signal(
        BilIntegrationSource.safety,
        selected?.safetyEligible == true ? 1 : 0,
        selected?.safetyEligible == true,
        true,
        'local-safety',
      ),
      _signal(
        BilIntegrationSource.coach,
        selected == null ? 0 : 0.8,
        selected != null,
        false,
        'coach-ready',
      ),
      _signal(
        BilIntegrationSource.healthInsight,
        coverage,
        coverage >= 0.45,
        false,
        'local-summary',
      ),
      _signal(
        BilIntegrationSource.proprietaryIntelligence,
        noise.confidence,
        noise.confidence >= 0.45,
        true,
        'bil-physiology',
      ),
      _signal(
        BilIntegrationSource.scientificValidation,
        0.85,
        true,
        true,
        'deterministic-trace',
      ),
    ];
    final issues = <String>[
      if (timeline.weightedDays.length < 2) 'hard:insufficient-weight-history',
      if (coverage < 0.35) 'insufficient-local-data-coverage',
      if (selected == null) 'no-safe-action-candidate',
    ];
    final brain = integration.integrateSignals(
      generatedAt: asOf,
      signals: signals,
      candidateAction: selected,
      reconciliationIssues: issues,
    );
    final message = selected == null
        ? 'BIL needs more local data before recommending an action.'
        : selected.title;
    return ProductIntelligenceOutput(
      brainResult: brain,
      noiseEstimate: noise,
      forecast: forecast,
      adaptiveTdeeKcal: tdee,
      plateauRisk: plateauRisk,
      primaryMessage: message,
      explanation: [
        ...noise.explanations,
        'Adaptive TDEE blends profile physiology with observed local energy balance.',
        'Plateau risk combines projected tissue velocity, adherence coverage and transient scale noise.',
        'The final action is generated locally and passed through Unified Health Brain confidence fusion.',
      ],
    );
  }

  List<RuntimeForecastPoint> _forecast(
    LocalIntelligenceTimeline timeline,
    double tdee,
    PhysiologicalNoiseEstimate noise,
  ) {
    final latest = timeline.weightedDays.isEmpty
        ? 0.0
        : timeline.weightedDays.last.weightKg!;
    final logged = timeline.days.where((day) => day.caloriesKcal > 0).toList();
    final intake = logged.isEmpty
        ? tdee
        : logged.fold<double>(0, (sum, day) => sum + day.caloriesKcal) /
              logged.length;
    final dailyTissue = (intake - tdee) / 7700;
    final baseConfidence =
        (noise.confidence * (0.55 + (_coverage(timeline) * 0.45))).clamp(
          0.0,
          1.0,
        );
    return [7, 14]
        .map((days) {
          final tissue = dailyTissue * days;
          final decayedNoise =
              noise.waterAndGlycogenNoiseKg * math.exp(-days / 4.0);
          return RuntimeForecastPoint(
            days: days,
            projectedWeightKg: latest + tissue + decayedNoise,
            projectedTissueChangeKg: tissue,
            confidence: (baseConfidence - ((days - 7) * 0.015)).clamp(0.0, 1.0),
          );
        })
        .toList(growable: false);
  }

  double _plateauRisk(
    LocalIntelligenceTimeline timeline,
    List<RuntimeForecastPoint> forecast,
    PhysiologicalNoiseEstimate noise,
  ) {
    final tissueVelocity = forecast.first.projectedTissueChangeKg.abs() / 7;
    final lowVelocity = (1 - (tissueVelocity / 0.07)).clamp(0.0, 1.0);
    final noiseMasking = (noise.waterAndGlycogenNoiseKg.abs() / 1.5).clamp(
      0.0,
      1.0,
    );
    final missing = 1 - _coverage(timeline);
    return ((lowVelocity * 0.55) + (noiseMasking * 0.25) + (missing * 0.2))
        .clamp(0.0, 1.0);
  }

  List<OneBestActionCandidate> _candidates(
    LocalIntelligenceTimeline timeline,
    PhysiologicalNoiseEstimate noise,
    List<RuntimeForecastPoint> forecast,
    double plateauRisk,
  ) {
    final recent = timeline.days.reversed.take(7).toList();
    final waterDays = recent.where((day) => day.waterMl > 0).toList();
    final averageWater = waterDays.isEmpty
        ? 0
        : waterDays.fold<int>(0, (sum, day) => sum + day.waterMl) /
              waterDays.length;
    final candidates = <OneBestActionCandidate>[];
    if (averageWater < 1800) {
      candidates.add(
        _candidate(
          'hydrate-consistently',
          'Stabilize daily hydration',
          'Low recorded water intake reduces confidence in scale interpretation.',
          0.75,
          0.8,
          0.15,
        ),
      );
    }
    if (noise.waterAndGlycogenNoiseKg.abs() > 0.5) {
      candidates.add(
        _candidate(
          'hold-course',
          'Hold the current plan for 3–4 days',
          'The physiology model indicates transient water, glycogen or digestive mass is masking tissue trend.',
          0.82,
          noise.confidence,
          0.08,
        ),
      );
    }
    if (plateauRisk > 0.65 &&
        forecast.first.projectedTissueChangeKg.abs() < 0.2) {
      candidates.add(
        _candidate(
          'audit-energy-intake',
          'Audit logged intake consistency',
          'Projected tissue velocity is low and plateau risk is elevated.',
          0.78,
          forecast.first.confidence,
          0.28,
        ),
      );
    }
    if (candidates.isEmpty) {
      candidates.add(
        _candidate(
          'continue-plan',
          'Continue the current plan',
          'Local trend, forecast and physiology signals do not justify a disruptive change.',
          0.7,
          noise.confidence,
          0.05,
        ),
      );
    }
    candidates.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));
    return candidates;
  }

  OneBestActionCandidate _candidate(
    String id,
    String title,
    String rationale,
    double benefit,
    double confidence,
    double burden,
  ) {
    return OneBestActionCandidate(
      id: id,
      title: title,
      rationale: rationale,
      expectedBenefit: benefit,
      confidence: confidence.clamp(0.0, 1.0),
      burden: burden,
      safetyEligible: true,
      evidenceIds: ['local-runtime:$id'],
    );
  }

  BilIntegrationSignal _signal(
    BilIntegrationSource source,
    double confidence,
    bool accepted,
    bool critical,
    String evidence,
  ) {
    return BilIntegrationSignal(
      source: source,
      confidence: confidence.clamp(0.0, 1.0),
      accepted: accepted,
      critical: critical,
      evidenceIds: [evidence],
      reasons: accepted ? const [] : ['local runtime gate not satisfied'],
    );
  }

  double _coverage(LocalIntelligenceTimeline timeline) {
    if (timeline.days.isEmpty) return 0;
    final covered = timeline.days
        .where(
          (day) =>
              day.weightKg != null || day.caloriesKcal > 0 || day.waterMl > 0,
        )
        .length;
    return covered / timeline.days.length;
  }
}
