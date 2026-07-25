import 'dart:collection';

enum HealthAiLearningState {
  unavailable,
  initial,
  learning,
  calibrating,
  established,
  temporarilyUnreliable,
}

final class WeightObservation {
  const WeightObservation({
    required this.at,
    required this.kg,
    this.comparability = 0.7,
  });

  final DateTime at;
  final double kg;
  final double comparability;
}

final class WeightTrendEstimate {
  WeightTrendEstimate({
    required this.state,
    required this.observedChangeKg,
    required this.kgPerDay,
    required this.lowerKgPerDay,
    required this.upperKgPerDay,
    required this.confidence,
    required this.observationCount,
    required Iterable<String> evidence,
    required Iterable<String> missingEvidence,
  }) : evidence = UnmodifiableListView(evidence.toList()),
       missingEvidence = UnmodifiableListView(missingEvidence.toList());

  final HealthAiLearningState state;
  final double? observedChangeKg;
  final double? kgPerDay;
  final double? lowerKgPerDay;
  final double? upperKgPerDay;
  final double confidence;
  final int observationCount;
  final List<String> evidence;
  final List<String> missingEvidence;
}

final class AdaptiveTdeeEstimate {
  AdaptiveTdeeEstimate({
    required this.state,
    required this.kcal,
    required this.lowerKcal,
    required this.upperKcal,
    required this.confidence,
    required this.formulaPriorKcal,
    required Iterable<String> evidence,
    required Iterable<String> missingEvidence,
  }) : evidence = UnmodifiableListView(evidence.toList()),
       missingEvidence = UnmodifiableListView(missingEvidence.toList());

  final HealthAiLearningState state;
  final double kcal;
  final double lowerKcal;
  final double upperKcal;
  final double confidence;
  final double formulaPriorKcal;
  final List<String> evidence;
  final List<String> missingEvidence;
}

final class TissueFluidEstimate {
  TissueFluidEstimate({
    required this.observedChangeKg,
    required this.probableTissueChangeKg,
    required this.probableFluidChangeKg,
    required this.unexplainedChangeKg,
    required this.confidence,
    required Iterable<String> evidence,
    required Iterable<String> missingEvidence,
  }) : evidence = UnmodifiableListView(evidence.toList()),
       missingEvidence = UnmodifiableListView(missingEvidence.toList());

  final double? observedChangeKg;
  final double? probableTissueChangeKg;
  final double? probableFluidChangeKg;
  final double? unexplainedChangeKg;
  final double confidence;
  final List<String> evidence;
  final List<String> missingEvidence;
}

final class PersonalHealthAiSnapshot {
  const PersonalHealthAiSnapshot({
    required this.asOf,
    required this.fullJourney,
    required this.currentPhase,
    required this.tdee,
    required this.tissueFluid,
    required this.plateauState,
    required this.goalForecastState,
  });

  final DateTime asOf;
  final WeightTrendEstimate fullJourney;
  final WeightTrendEstimate currentPhase;
  final AdaptiveTdeeEstimate tdee;
  final TissueFluidEstimate tissueFluid;
  final HealthAiLearningState plateauState;
  final HealthAiLearningState goalForecastState;
}
