import 'bil_intelligence_integration.dart';

final class BilIntelligenceIntegrationPolicy {
  BilIntelligenceIntegrationPolicy({
    this.minimumUnifiedConfidence = 0.62,
    this.maximumCriticalFailures = 0,
    this.conflictPenalty = 0.08,
    Map<BilIntegrationSource, double>? sourceWeights,
  }) : sourceWeights = Map.unmodifiable(
         sourceWeights ??
             const <BilIntegrationSource, double>{
               BilIntegrationSource.aiContext: 1.25,
               BilIntegrationSource.bodyTwin: 1.25,
               BilIntegrationSource.decisionMemory: 0.65,
               BilIntegrationSource.adaptiveForecast: 0.9,
               BilIntegrationSource.tissueWater: 0.9,
               BilIntegrationSource.oneBestAction: 1.35,
               BilIntegrationSource.safety: 1.5,
               BilIntegrationSource.coach: 0.55,
               BilIntegrationSource.healthInsight: 0.55,
               BilIntegrationSource.proprietaryIntelligence: 1.1,
               BilIntegrationSource.scientificValidation: 1.35,
             },
       ) {
    if (minimumUnifiedConfidence < 0 || minimumUnifiedConfidence > 1) {
      throw ArgumentError.value(
        minimumUnifiedConfidence,
        'minimumUnifiedConfidence',
        'must be in [0, 1]',
      );
    }
    if (maximumCriticalFailures < 0) {
      throw ArgumentError.value(
        maximumCriticalFailures,
        'maximumCriticalFailures',
        'must not be negative',
      );
    }
    if (conflictPenalty < 0 || conflictPenalty > 1) {
      throw ArgumentError.value(
        conflictPenalty,
        'conflictPenalty',
        'must be in [0, 1]',
      );
    }
    if (this.sourceWeights.values.any((weight) => weight <= 0)) {
      throw ArgumentError.value(
        sourceWeights,
        'sourceWeights',
        'weights must be positive',
      );
    }
  }

  final double minimumUnifiedConfidence;
  final int maximumCriticalFailures;
  final double conflictPenalty;
  final Map<BilIntegrationSource, double> sourceWeights;
}
