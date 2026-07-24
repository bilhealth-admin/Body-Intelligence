import 'package:body_intelligence_log/features/ai_platform/domain/adaptive_metabolic_forecast.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/adaptive_metabolic_forecast_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_context.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/tissue_water_noise_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_explain_foundation_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/adaptive_metabolic_forecast_engine.dart';
import 'package:body_intelligence_log/features/ai_platform/services/tissue_water_noise_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'rejects incomplete upstream results and exposes no forecast points',
    () {
      final result = const AdaptiveMetabolicForecastEngine().forecast<void>(
        contextResult: AiContextEngineResult<void>(
          context: AiContext<void>(
            asOf: DateTime.utc(2026, 7, 24),
            truthStatus: TruthExplainFoundationStatus.abstention,
            truthDecision: null,
            bodySnapshot: null,
            bodyTrends: null,
            decisionHistory: const [],
            missingContextKeys: const <String>['body.trends'],
            provenance: const [],
          ),
          integrityIssues: const [],
          upstreamRejected: false,
        ),
        noiseResult: TissueWaterNoiseEngineResult(
          analysis: TissueWaterNoiseAnalysis(
            classification: TissueWaterNoiseClassification.insufficientEvidence,
            observedChangeKg: null,
            supportedTissueChangeKg: null,
            isolatedWaterNoiseKg: null,
            confidence: 0,
            evidenceIds: const [],
            uncertaintyReasons: const <String>['missing evidence'],
            alternativeExplanations: const [],
          ),
          integrityIssues: const [],
        ),
        policy: const AdaptiveMetabolicForecastPolicy(
          horizons: <Duration>[Duration(days: 7)],
        ),
        supportedDailyEnergyBalanceKcal: -500,
        energyEvidenceConfidence: 1,
        energyEvidenceIds: const <String>['ledger'],
        assumptionIds: const <String>['constant-balance'],
      );
      expect(result.canProceed, isFalse);
      expect(result.forecast.status, AdaptiveMetabolicForecastStatus.rejected);
      expect(result.forecast.points, isEmpty);
    },
  );

  test('normalizes ordering of horizons and evidence deterministically', () {
    final context = AiContextEngineResult<void>(
      context: AiContext<void>(
        asOf: DateTime.utc(2026, 7, 24),
        truthStatus: TruthExplainFoundationStatus.abstention,
        truthDecision: null,
        bodySnapshot: null,
        bodyTrends: null,
        decisionHistory: const [],
        missingContextKeys: const [],
        provenance: const [],
      ),
      integrityIssues: const [],
      upstreamRejected: false,
    );
    final noise = TissueWaterNoiseEngineResult(
      analysis: TissueWaterNoiseAnalysis(
        classification: TissueWaterNoiseClassification.mixed,
        observedChangeKg: -1,
        supportedTissueChangeKg: -0.4,
        isolatedWaterNoiseKg: -0.6,
        confidence: 0.9,
        evidenceIds: const <String>['b', 'a'],
        uncertaintyReasons: const [],
        alternativeExplanations: const [],
      ),
      integrityIssues: const [],
    );
    final result = const AdaptiveMetabolicForecastEngine().forecast<void>(
      contextResult: context,
      noiseResult: noise,
      policy: const AdaptiveMetabolicForecastPolicy(
        horizons: <Duration>[Duration(days: 14), Duration(days: 7)],
      ),
      supportedDailyEnergyBalanceKcal: -500,
      energyEvidenceConfidence: 0.9,
      energyEvidenceIds: const <String>['z', 'y'],
      assumptionIds: const <String>['b', 'a'],
    );
    expect(result.forecast.points.map((point) => point.horizon.inDays), <int>[
      7,
      14,
    ]);
    expect(result.forecast.assumptionIds, <String>['a', 'b']);
    expect(result.forecast.evidenceIds, <String>['a', 'b', 'y', 'z']);
  });
}
