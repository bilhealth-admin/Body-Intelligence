import 'dart:collection';

enum TissueWaterNoiseClassification {
  tissueDominant,
  waterDominant,
  mixed,
  insufficientEvidence,
  rejected,
}

final class TissueWaterNoiseAnalysis {
  TissueWaterNoiseAnalysis({
    required this.classification,
    required this.observedChangeKg,
    required this.supportedTissueChangeKg,
    required this.isolatedWaterNoiseKg,
    required this.confidence,
    required Iterable<String> evidenceIds,
    required Iterable<String> uncertaintyReasons,
    required Iterable<String> alternativeExplanations,
  }) : evidenceIds = UnmodifiableListView<String>(
         (evidenceIds.toSet().toList()..sort()),
       ),
       uncertaintyReasons = UnmodifiableListView<String>(
         (uncertaintyReasons.toSet().toList()..sort()),
       ),
       alternativeExplanations = UnmodifiableListView<String>(
         (alternativeExplanations.toSet().toList()..sort()),
       ) {
    if (confidence < 0 || confidence > 1) {
      throw ArgumentError.value(confidence, 'confidence', 'must be in [0, 1]');
    }
  }

  final TissueWaterNoiseClassification classification;
  final double? observedChangeKg;
  final double? supportedTissueChangeKg;
  final double? isolatedWaterNoiseKg;
  final double confidence;
  final List<String> evidenceIds;
  final List<String> uncertaintyReasons;
  final List<String> alternativeExplanations;

  bool get canProceed =>
      classification != TissueWaterNoiseClassification.rejected &&
      classification != TissueWaterNoiseClassification.insufficientEvidence;
}
