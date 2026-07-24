import 'package:body_intelligence_log/features/ai_platform/domain/ai_context.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/tissue_water_noise_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/tissue_water_noise_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_explain_foundation_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/tissue_water_noise_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejected context cannot produce an accepted isolation', () {
    final context = AiContext<void>(
      asOf: DateTime.utc(2026, 7, 2),
      truthStatus: TruthExplainFoundationStatus.rejected,
      truthDecision: null,
      bodySnapshot: null,
      bodyTrends: null,
      decisionHistory: const [],
      missingContextKeys: const ['body.trends'],
      provenance: const [],
    );
    final result = const TissueWaterNoiseEngine().analyze<void>(
      contextResult: AiContextEngineResult<void>(
        context: context,
        integrityIssues: const [],
        upstreamRejected: true,
      ),
      policy: const TissueWaterNoisePolicy(),
      supportedTissueChangeKg: -0.2,
      tissueEvidenceIds: const ['fixture'],
    );

    expect(result.canProceed, isFalse);
    expect(
      result.analysis.classification,
      TissueWaterNoiseClassification.rejected,
    );
  });

  test('policy validation prevents false precision', () {
    expect(
      () => const TissueWaterNoisePolicy(minimumObservations: 1).validate(),
      throwsArgumentError,
    );
    expect(
      () => const TissueWaterNoiseEngine().analyze<void>(
        contextResult: AiContextEngineResult<void>(
          context: AiContext<void>(
            asOf: DateTime.utc(2026, 7, 2),
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
        ),
        policy: const TissueWaterNoisePolicy(),
        supportedTissueChangeKg: 0,
        tissueEvidenceIds: const ['fixture'],
        evidenceConfidence: 1.1,
      ),
      throwsArgumentError,
    );
  });
}
