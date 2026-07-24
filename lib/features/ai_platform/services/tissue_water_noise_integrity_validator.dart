import '../domain/tissue_water_noise_analysis.dart';

final class TissueWaterNoiseIntegrityValidator {
  const TissueWaterNoiseIntegrityValidator();

  List<String> validate(TissueWaterNoiseAnalysis analysis) {
    final issues = <String>[];
    if (analysis.canProceed) {
      if (analysis.observedChangeKg == null ||
          analysis.supportedTissueChangeKg == null ||
          analysis.isolatedWaterNoiseKg == null) {
        issues.add('accepted analysis is missing a numeric component');
      }
      if (analysis.evidenceIds.isEmpty) {
        issues.add('accepted analysis is missing evidence');
      }
      if (analysis.confidence <= 0) {
        issues.add('accepted analysis must have positive confidence');
      }
    }
    if (analysis.classification ==
            TissueWaterNoiseClassification.insufficientEvidence &&
        analysis.uncertaintyReasons.isEmpty) {
      issues.add('insufficient evidence must remain explicit');
    }
    return issues..sort();
  }
}
