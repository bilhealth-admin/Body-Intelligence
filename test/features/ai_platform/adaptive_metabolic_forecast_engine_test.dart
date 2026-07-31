import 'package:body_intelligence_log/features/ai_platform/domain/adaptive_metabolic_forecast.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/adaptive_metabolic_forecast_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_context.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/tissue_water_noise_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_explain_foundation_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/adaptive_metabolic_forecast_engine.dart';
import 'package:body_intelligence_log/features/ai_platform/services/tissue_water_noise_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projects explicit horizons from caller-supported energy evidence', () {
    final result = const AdaptiveMetabolicForecastEngine().forecast<void>(
      contextResult: _context(),
      noiseResult: _noise(),
      policy: const AdaptiveMetabolicForecastPolicy(
        horizons: <Duration>[Duration(days: 7), Duration(days: 14)],
      ),
      supportedDailyEnergyBalanceKcal: -770,
      energyEvidenceConfidence: 0.8,
      energyEvidenceIds: const <String>['ledger:energy-7d'],
      assumptionIds: const <String>['energy-balance-held-constant'],
    );
    expect(result.canProceed, isTrue);
    expect(result.forecast.status, AdaptiveMetabolicForecastStatus.accepted);
    expect(
      result.forecast.points.first.projectedTissueChangeKg,
      closeTo(-0.7, 0.0001),
    );
    expect(
      result.forecast.points.last.projectedTissueChangeKg,
      closeTo(-1.4, 0.0001),
    );
  });

  test('abstains rather than inventing missing energy evidence', () {
    final result = const AdaptiveMetabolicForecastEngine().forecast<void>(
      contextResult: _context(),
      noiseResult: _noise(),
      policy: const AdaptiveMetabolicForecastPolicy(
        horizons: <Duration>[Duration(days: 7)],
      ),
      supportedDailyEnergyBalanceKcal: null,
      energyEvidenceConfidence: 1,
    );
    expect(result.canProceed, isFalse);
    expect(result.forecast.status, AdaptiveMetabolicForecastStatus.abstained);
    expect(result.forecast.points, isEmpty);
  });
}

AiContextEngineResult<void> _context() => AiContextEngineResult<void>(
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

TissueWaterNoiseEngineResult _noise() => TissueWaterNoiseEngineResult(
  analysis: TissueWaterNoiseAnalysis(
    classification: TissueWaterNoiseClassification.mixed,
    observedChangeKg: -1,
    supportedTissueChangeKg: -0.4,
    isolatedWaterNoiseKg: -0.6,
    confidence: 0.8,
    evidenceIds: const <String>['weight:1', 'weight:2'],
    uncertaintyReasons: const <String>[],
    alternativeExplanations: const <String>[],
  ),
  integrityIssues: const [],
);
