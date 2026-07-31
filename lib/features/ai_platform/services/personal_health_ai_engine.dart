import 'dart:math' as math;

import '../domain/personal_health_ai.dart';

/// Deterministic, explainable online operating model.
///
/// Weight direction uses Theil-Sen (the median of every pairwise slope),
/// which naturally supports irregular timestamps and resists isolated
/// outliers. Its interval is the 10th-90th percentile pairwise slope range.
/// Adaptive TDEE uses the Mifflin-St Jeor prior and blends calibration only
/// when the calorie ledger covers at least half of the measured interval.
/// The energy-density conversion is an uncertain approximation (range
/// 6,500-9,500 kcal/kg), never a claim of measured fat change.
final class PersonalHealthAiEngine {
  const PersonalHealthAiEngine();

  PersonalHealthAiSnapshot evaluate({
    required DateTime asOf,
    required Iterable<WeightObservation> weights,
    required int age,
    required double heightCm,
    required String gender,
    required String activityLevel,
    required Map<DateTime, double?> dailyCalories,
  }) {
    final ordered =
        weights
            .where(
              (item) =>
                  item.kg.isFinite &&
                  item.kg > 20 &&
                  item.kg < 400 &&
                  !item.at.isAfter(asOf),
            )
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    final full = _trend(ordered);
    final phaseStart = asOf.subtract(const Duration(days: 28));
    final phase = ordered
        .where((item) => !item.at.isBefore(phaseStart))
        .toList();
    final current = _trend(phase.length >= 2 ? phase : ordered);
    final prior = _formulaTdee(
      weightKg: ordered.isEmpty ? null : ordered.last.kg,
      age: age,
      heightCm: heightCm,
      gender: gender,
      activityLevel: activityLevel,
    );
    final tdee = _adaptiveTdee(
      trend: current,
      weights: ordered,
      calories: dailyCalories,
      prior: prior,
    );
    final tissueFluid = _decompose(
      trend: current,
      weights: ordered,
      calories: dailyCalories,
      tdee: tdee,
    );
    final enoughForConclusions =
        current.observationCount >= 5 && current.confidence >= 0.55;
    return PersonalHealthAiSnapshot(
      asOf: asOf,
      fullJourney: full,
      currentPhase: current,
      tdee: tdee,
      tissueFluid: tissueFluid,
      plateauState: enoughForConclusions
          ? HealthAiLearningState.learning
          : HealthAiLearningState.initial,
      goalForecastState: current.observationCount >= 2
          ? (current.confidence >= 0.6
                ? HealthAiLearningState.calibrating
                : HealthAiLearningState.learning)
          : HealthAiLearningState.unavailable,
    );
  }

  WeightTrendEstimate _trend(List<WeightObservation> values) {
    if (values.length < 2) {
      return WeightTrendEstimate(
        state: values.isEmpty
            ? HealthAiLearningState.unavailable
            : HealthAiLearningState.initial,
        observedChangeKg: null,
        kgPerDay: null,
        lowerKgPerDay: null,
        upperKgPerDay: null,
        confidence: 0,
        observationCount: values.length,
        evidence: values.isEmpty ? const [] : const ['one valid weight'],
        missingEvidence: const ['a second valid weight measurement'],
      );
    }
    final slopes = <double>[];
    for (var i = 0; i < values.length - 1; i++) {
      for (var j = i + 1; j < values.length; j++) {
        final hours = values[j].at.difference(values[i].at).inMinutes / 60;
        if (hours < 4) continue;
        slopes.add((values[j].kg - values[i].kg) / (hours / 24));
      }
    }
    if (slopes.isEmpty) {
      return WeightTrendEstimate(
        state: HealthAiLearningState.temporarilyUnreliable,
        observedChangeKg: values.last.kg - values.first.kg,
        kgPerDay: null,
        lowerKgPerDay: null,
        upperKgPerDay: null,
        confidence: 0,
        observationCount: values.length,
        evidence: const ['valid weights'],
        missingEvidence: const ['enough elapsed time between measurements'],
      );
    }
    slopes.sort();
    final slope = _quantile(slopes, 0.5);
    final lower = _quantile(slopes, 0.1);
    final upper = _quantile(slopes, 0.9);
    final spanDays = math.max(
      0.25,
      values.last.at.difference(values.first.at).inMinutes / 1440,
    );
    final density = (values.length / 10).clamp(0.0, 1.0);
    final duration = (spanDays / 28).clamp(0.0, 1.0);
    final agreement = (1 - ((upper - lower).abs() / 0.35)).clamp(0.0, 1.0);
    final comparability =
        values
            .map((item) => item.comparability.clamp(0.0, 1.0))
            .reduce((a, b) => a + b) /
        values.length;
    final confidence =
        ((0.10 + density * 0.30 + duration * 0.25 + agreement * 0.20) *
                comparability)
            .clamp(0.05, 0.95);
    return WeightTrendEstimate(
      state: values.length == 2
          ? HealthAiLearningState.initial
          : confidence >= 0.7
          ? HealthAiLearningState.established
          : HealthAiLearningState.learning,
      observedChangeKg: values.last.kg - values.first.kg,
      kgPerDay: slope,
      lowerKgPerDay: lower,
      upperKgPerDay: upper,
      confidence: confidence,
      observationCount: values.length,
      evidence: [
        '${values.length} valid weights',
        '${spanDays.toStringAsFixed(1)} elapsed days',
        'measurement timestamps',
      ],
      missingEvidence: values.length < 5
          ? const ['more comparable measurements to narrow uncertainty']
          : const [],
    );
  }

  AdaptiveTdeeEstimate _adaptiveTdee({
    required WeightTrendEstimate trend,
    required List<WeightObservation> weights,
    required Map<DateTime, double?> calories,
    required double prior,
  }) {
    if (prior <= 0 || weights.isEmpty) {
      return AdaptiveTdeeEstimate(
        state: HealthAiLearningState.unavailable,
        kcal: 0,
        lowerKcal: 0,
        upperKcal: 0,
        confidence: 0,
        formulaPriorKcal: 0,
        evidence: const [],
        missingEvidence: const ['profile and first weight'],
      );
    }
    if (weights.length < 2 || trend.kgPerDay == null) {
      return _priorTdee(prior, const ['a second valid weight']);
    }
    final start = DateTime(
      weights.first.at.year,
      weights.first.at.month,
      weights.first.at.day,
    );
    final end = DateTime(
      weights.last.at.year,
      weights.last.at.month,
      weights.last.at.day,
    );
    final intervalDays = math.max(1, end.difference(start).inDays + 1);
    final logged = calories.entries
        .where(
          (entry) =>
              !entry.key.isBefore(start) &&
              !entry.key.isAfter(end) &&
              entry.value != null &&
              entry.value! > 0,
        )
        .map((entry) => entry.value!)
        .toList();
    final coverage = logged.length / intervalDays;
    if (logged.length < 2 || coverage < 0.5) {
      return _priorTdee(prior, const [
        'complete calorie intake for at least half the interval',
      ]);
    }
    final intake = logged.reduce((a, b) => a + b) / logged.length;
    final observed = intake - trend.kgPerDay! * 7700;
    final bounded = observed.clamp(prior * 0.7, prior * 1.3);
    final calibrationWeight = (0.1 + coverage * 0.35 + trend.confidence * 0.25)
        .clamp(0.1, 0.6);
    final estimate =
        prior * (1 - calibrationWeight) + bounded * calibrationWeight;
    final uncertainty =
        150 + (1 - coverage) * 350 + (1 - trend.confidence) * 300;
    return AdaptiveTdeeEstimate(
      state: coverage >= 0.8 && trend.confidence >= 0.65
          ? HealthAiLearningState.established
          : HealthAiLearningState.calibrating,
      kcal: estimate.roundToDouble(),
      lowerKcal: math.max(800, estimate - uncertainty).roundToDouble(),
      upperKcal: (estimate + uncertainty).roundToDouble(),
      confidence: (coverage * 0.55 + trend.confidence * 0.45).clamp(0.0, 0.9),
      formulaPriorKcal: prior,
      evidence: [
        '${logged.length} logged calorie days',
        '${(coverage * 100).round()}% interval coverage',
        'robust weight trend',
      ],
      missingEvidence: coverage < 0.8
          ? const ['more complete calorie days']
          : const [],
    );
  }

  AdaptiveTdeeEstimate _priorTdee(double prior, List<String> missing) =>
      AdaptiveTdeeEstimate(
        state: HealthAiLearningState.initial,
        kcal: prior.roundToDouble(),
        lowerKcal: (prior * 0.8).roundToDouble(),
        upperKcal: (prior * 1.2).roundToDouble(),
        confidence: 0.25,
        formulaPriorKcal: prior,
        evidence: const ['Mifflin-St Jeor profile prior'],
        missingEvidence: missing,
      );

  TissueFluidEstimate _decompose({
    required WeightTrendEstimate trend,
    required List<WeightObservation> weights,
    required Map<DateTime, double?> calories,
    required AdaptiveTdeeEstimate tdee,
  }) {
    if (weights.length < 2) {
      return TissueFluidEstimate(
        observedChangeKg: null,
        probableTissueChangeKg: null,
        probableFluidChangeKg: null,
        unexplainedChangeKg: null,
        confidence: 0,
        evidence: const [],
        missingEvidence: const ['two valid weights', 'calorie evidence'],
      );
    }
    final observed = weights.last.kg - weights.first.kg;
    if (tdee.state == HealthAiLearningState.initial ||
        tdee.state == HealthAiLearningState.unavailable) {
      return TissueFluidEstimate(
        observedChangeKg: observed,
        probableTissueChangeKg: null,
        probableFluidChangeKg: null,
        unexplainedChangeKg: observed,
        confidence: math.min(0.25, trend.confidence),
        evidence: const ['observed scale change', 'robust early direction'],
        missingEvidence: const [
          'sufficient calorie evidence to separate tissue and fluid reliably',
        ],
      );
    }
    final values = calories.values
        .whereType<double>()
        .where((value) => value > 0)
        .toList();
    final average = values.reduce((a, b) => a + b) / values.length;
    final days = math.max(
      0.25,
      weights.last.at.difference(weights.first.at).inMinutes / 1440,
    );
    final tissue = ((average - tdee.kcal) * days) / 7700;
    final residual = observed - tissue;
    return TissueFluidEstimate(
      observedChangeKg: observed,
      probableTissueChangeKg: tissue,
      probableFluidChangeKg: residual * 0.65,
      unexplainedChangeKg: residual * 0.35,
      confidence: math.min(tdee.confidence, trend.confidence),
      evidence: const [
        'observed scale change',
        'calorie-supported energy balance',
        'robust weight trend',
      ],
      missingEvidence: const [
        'direct tissue measurement; energy density is an approximation',
      ],
    );
  }

  double _formulaTdee({
    required double? weightKg,
    required int age,
    required double heightCm,
    required String gender,
    required String activityLevel,
  }) {
    if (weightKg == null || age <= 0 || heightCm <= 0) return 0;
    final offset = gender.toLowerCase().startsWith('f') ? -161.0 : 5.0;
    final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + offset;
    final factor = switch (activityLevel) {
      'veryActive' => 1.725,
      'active' => 1.55,
      'moderate' => 1.375,
      _ => 1.2,
    };
    return bmr * factor;
  }

  double _quantile(List<double> sorted, double q) {
    if (sorted.length == 1) return sorted.single;
    final position = (sorted.length - 1) * q;
    final low = position.floor();
    final high = position.ceil();
    if (low == high) return sorted[low];
    return sorted[low] + (sorted[high] - sorted[low]) * (position - low);
  }
}
