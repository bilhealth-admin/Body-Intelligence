import 'package:body_intelligence_log/features/ai_platform/domain/ai_context.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_trend_state.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/tissue_water_noise_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/tissue_water_noise_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_explain_foundation_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/tissue_water_noise_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isolates residual water/noise with explicit evidence', () {
    final result = const TissueWaterNoiseEngine().analyze<void>(
      contextResult: _acceptedContext(),
      policy: const TissueWaterNoisePolicy(),
      supportedTissueChangeKg: -0.4,
      tissueEvidenceIds: const <String>['energy-ledger:week-1'],
      waterSignalEvidenceIds: const <String>['sodium:day-2'],
      evidenceConfidence: 0.8,
    );

    expect(result.canProceed, isTrue);
    expect(result.analysis.observedChangeKg, closeTo(-1.0, 0.0001));
    expect(result.analysis.isolatedWaterNoiseKg, closeTo(-0.6, 0.0001));
    expect(
      result.analysis.classification,
      TissueWaterNoiseClassification.mixed,
    );
    expect(result.analysis.confidence, 0.8);
  });

  test('abstains when supported tissue evidence is absent', () {
    final result = const TissueWaterNoiseEngine().analyze<void>(
      contextResult: _acceptedContext(),
      policy: const TissueWaterNoisePolicy(),
      supportedTissueChangeKg: null,
    );

    expect(result.canProceed, isFalse);
    expect(
      result.analysis.classification,
      TissueWaterNoiseClassification.insufficientEvidence,
    );
    expect(result.analysis.uncertaintyReasons, isNotEmpty);
  });
}

AiContextEngineResult<void> _acceptedContext() {
  final trend = BodyTwinMetricTrend(
    metricKey: 'weight',
    observations: <BodyTwinObservation>[
      BodyTwinObservation(
        metricKey: 'weight',
        value: 96,
        unit: 'kg',
        observedAt: DateTime.utc(2026, 7, 1),
        source: 'manual',
      ),
      BodyTwinObservation(
        metricKey: 'weight',
        value: 95,
        unit: 'kg',
        observedAt: DateTime.utc(2026, 7, 2),
        source: 'manual',
      ),
    ],
  );
  final context = AiContext<void>(
    asOf: DateTime.utc(2026, 7, 2),
    truthStatus: TruthExplainFoundationStatus.abstention,
    truthDecision: null,
    bodySnapshot: null,
    bodyTrends: BodyTwinTrendState(
      asOf: DateTime.utc(2026, 7, 2),
      trendsByMetric: <String, BodyTwinMetricTrend>{'weight': trend},
    ),
    decisionHistory: const [],
    missingContextKeys: const [],
    provenance: const [],
  );
  return AiContextEngineResult<void>(
    context: context,
    integrityIssues: const [],
    upstreamRejected: false,
  );
}
