import 'dart:math' as math;

import '../domain/adaptive_metabolic_forecast.dart';
import '../domain/decision_memory_history.dart';
import '../domain/decision_outcome_transition.dart';
import '../domain/local_intelligence_runtime.dart';
import '../domain/one_best_action.dart';

/// Deterministic product-facing behavior layer over accepted engine outputs.
///
/// It translates forecast output, derives plateau risk, generates adaptive
/// action candidates, and applies append-only Decision Memory outcome effects.
final class ProductIntelligenceBehaviorModel {
  const ProductIntelligenceBehaviorModel();

  List<RuntimeForecastPoint> productForecast({
    required AdaptiveMetabolicForecastResult result,
    required double latestWeightKg,
  }) {
    final accepted = result.acceptedForecast;
    if (accepted == null) return const <RuntimeForecastPoint>[];
    return [
      for (final point in accepted.points)
        RuntimeForecastPoint(
          days: point.horizon.inDays,
          projectedWeightKg: latestWeightKg + point.projectedScaleChangeKg,
          projectedTissueChangeKg: point.projectedTissueChangeKg,
          confidence: point.confidence,
        ),
    ];
  }

  double plateauRisk({
    required LocalIntelligenceTimeline timeline,
    required double adaptiveTdeeKcal,
    required double? averageIntakeKcal,
    required AdaptiveMetabolicForecastResult forecastResult,
    required double physiologyConfidence,
  }) {
    final weighted = timeline.weightedDays;
    if (weighted.length < 2 ||
        averageIntakeKcal == null ||
        adaptiveTdeeKcal <= 0) {
      return 1;
    }
    final spanDays = math.max(
      1,
      weighted.last.day.difference(weighted.first.day).inDays,
    );
    final weeklyRateKg =
        ((weighted.last.weightKg! - weighted.first.weightKg!) / spanDays) * 7;
    final energyDeficit = adaptiveTdeeKcal - averageIntakeKcal;
    final expectedWeeklyLoss = math.max(0, energyDeficit * 7 / 7700);
    final slowdown = expectedWeeklyLoss <= 0.05
        ? 1.0
        : (1 - ((-weeklyRateKg) / expectedWeeklyLoss)).clamp(0.0, 1.0);
    final recent = weighted.length >= 4
        ? weighted.sublist(weighted.length - 4)
        : weighted;
    final recentSpan = math.max(
      1,
      recent.last.day.difference(recent.first.day).inDays,
    );
    final recentWeeklyRate =
        ((recent.last.weightKg! - recent.first.weightKg!) / recentSpan) * 7;
    final flatTrend = (1 - ((recentWeeklyRate.abs() / 0.5).clamp(0.0, 1.0)));
    final forecastPenalty = forecastResult.canProceed ? 0.0 : 0.25;
    final uncertainty = 1 - physiologyConfidence.clamp(0.0, 1.0);
    return ((slowdown * 0.45) +
            (flatTrend * 0.25) +
            (uncertainty * 0.2) +
            forecastPenalty)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  List<OneBestActionCandidate> candidates({
    required LocalIntelligenceTimeline timeline,
    required PhysiologicalNoiseEstimate estimate,
    required double adaptiveTdeeKcal,
    required double? averageIntakeKcal,
    required double plateauRisk,
  }) {
    final logged = timeline.days.where((day) => day.caloriesKcal > 0).toList();
    final avgProtein = logged.isEmpty
        ? 0.0
        : logged.fold<double>(0, (sum, day) => sum + day.proteinG) /
              logged.length;
    final avgSodium = logged.isEmpty
        ? 0.0
        : logged.fold<double>(0, (sum, day) => sum + day.sodiumMg) /
              logged.length;
    final avgPotassium = logged.isEmpty
        ? 0.0
        : logged.fold<double>(0, (sum, day) => sum + day.potassiumMg) /
              logged.length;
    final avgWater = logged.isEmpty
        ? 0.0
        : logged.fold<double>(0, (sum, day) => sum + day.waterMl) /
              logged.length;
    final sleepDays = timeline.days
        .where((day) => day.sleepHours != null)
        .toList();
    final avgSleep = sleepDays.isEmpty
        ? null
        : sleepDays.fold<double>(0, (sum, day) => sum + day.sleepHours!) /
              sleepDays.length;
    final stepDays = timeline.days.where((day) => day.steps != null).toList();
    final avgSteps = stepDays.isEmpty
        ? null
        : stepDays.fold<double>(0, (sum, day) => sum + day.steps!) /
              stepDays.length;
    final targetGap = timeline.weightedDays.isEmpty
        ? 0.0
        : timeline.weightedDays.last.weightKg! - timeline.targetWeightKg;
    final deficit = averageIntakeKcal == null
        ? 0.0
        : adaptiveTdeeKcal - averageIntakeKcal;

    final candidates = <OneBestActionCandidate>[
      _candidate(
        id: 'continue-plan',
        title: 'Continue the current plan',
        rationale:
            'Energy balance, body trend, and target gap support stability.',
        benefit: plateauRisk < 0.55 ? 0.76 : 0.48,
        confidence: estimate.confidence,
        burden: 0.05,
        evidence: <String>[
          'local-physiology',
          if (averageIntakeKcal != null) 'local-energy-balance',
          if (targetGap != 0) 'local-target-gap',
        ],
      ),
      if (avgProtein > 0 && avgProtein < 1.4 * _referenceWeight(timeline))
        _candidate(
          id: 'increase-protein',
          title: 'Raise protein consistency',
          rationale:
              'Logged protein is below the local body-weight support threshold.',
          benefit: 0.82,
          confidence: _coverageConfidence(logged.length, timeline.days.length),
          burden: 0.18,
          evidence: const ['local-protein', 'local-weight'],
        ),
      if (avgSodium > 2600 && avgPotassium > 0 && avgPotassium < 3000)
        _candidate(
          id: 'rebalance-electrolytes',
          title: 'Rebalance sodium, potassium, and water',
          rationale:
              'High sodium with low potassium increases transient water-noise risk.',
          benefit: 0.86,
          confidence: estimate.confidence,
          burden: 0.16,
          evidence: <String>[
            'local-sodium',
            'local-potassium',
            if (avgWater > 0) 'local-water',
          ],
        ),
      if (avgSleep != null && avgSleep < 6.5)
        _candidate(
          id: 'protect-sleep',
          title: 'Protect sleep consistency',
          rationale:
              'Recent sleep duration is below the recovery support threshold.',
          benefit: 0.8,
          confidence: _coverageConfidence(
            sleepDays.length,
            timeline.days.length,
          ),
          burden: 0.15,
          evidence: const ['local-sleep'],
        ),
      if (avgSteps != null && avgSteps < 6000 && deficit < 900)
        _candidate(
          id: 'increase-activity',
          title: 'Increase low-intensity activity',
          rationale:
              'Activity is low while energy deficit remains within the safety boundary.',
          benefit: 0.74,
          confidence: _coverageConfidence(
            stepDays.length,
            timeline.days.length,
          ),
          burden: 0.2,
          evidence: const ['local-activity', 'local-energy-balance'],
        ),
      if (plateauRisk >= 0.6)
        _candidate(
          id: 'audit-plateau-inputs',
          title: 'Audit plateau drivers before changing calories',
          rationale:
              'The deterministic plateau score is elevated and needs evidence review.',
          benefit: 0.88,
          confidence: estimate.confidence,
          burden: 0.12,
          evidence: const ['local-plateau-risk', 'local-physiology'],
        ),
    ];

    return candidates
        .map((candidate) => _applyMemory(candidate, timeline.decisionHistory))
        .toList(growable: false);
  }

  OneBestActionCandidate _applyMemory(
    OneBestActionCandidate candidate,
    List<DecisionMemoryHistory> history,
  ) {
    final matching = history.where(
      (entry) =>
          entry.record.decisionKey == candidate.id ||
          entry.record.selectedAction == candidate.title,
    );
    var confidence = candidate.confidence;
    var benefit = candidate.expectedBenefit;
    final evidence = <String>{...candidate.evidenceIds};
    for (final entry in matching) {
      evidence.add('decision-memory:${entry.record.id}');
      if (entry.currentState == DecisionOutcomeState.succeeded) {
        confidence += 0.08;
        benefit += 0.05;
      } else if (entry.currentState == DecisionOutcomeState.failed) {
        confidence -= 0.22;
        benefit -= 0.18;
      }
    }
    return OneBestActionCandidate(
      id: candidate.id,
      title: candidate.title,
      rationale: candidate.rationale,
      expectedBenefit: benefit.clamp(0.0, 1.0).toDouble(),
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      burden: candidate.burden,
      safetyEligible: candidate.safetyEligible,
      evidenceIds: evidence,
    );
  }

  OneBestActionCandidate _candidate({
    required String id,
    required String title,
    required String rationale,
    required double benefit,
    required double confidence,
    required double burden,
    required List<String> evidence,
  }) {
    final cleanEvidence = evidence.where((value) => value.isNotEmpty).toList();
    final eligible =
        cleanEvidence.isNotEmpty && confidence >= 0.35 && benefit > burden;
    return OneBestActionCandidate(
      id: id,
      title: title,
      rationale: rationale,
      expectedBenefit: benefit.clamp(0.0, 1.0).toDouble(),
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      burden: burden.clamp(0.0, 1.0).toDouble(),
      safetyEligible: eligible,
      evidenceIds: cleanEvidence,
    );
  }

  double _referenceWeight(LocalIntelligenceTimeline timeline) =>
      timeline.weightedDays.isEmpty
      ? timeline.targetWeightKg
      : timeline.weightedDays.last.weightKg!;

  double _coverageConfidence(int available, int total) =>
      (0.35 + (available / math.max(1, total)) * 0.6)
          .clamp(0.0, 0.95)
          .toDouble();
}
