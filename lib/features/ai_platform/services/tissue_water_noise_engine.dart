import '../domain/ai_context.dart';
import '../domain/tissue_water_noise_analysis.dart';
import '../domain/tissue_water_noise_policy.dart';
import 'tissue_water_noise_integrity_validator.dart';

final class TissueWaterNoiseEngineResult {
  TissueWaterNoiseEngineResult({
    required this.analysis,
    required Iterable<String> integrityIssues,
  }) : integrityIssues = List<String>.unmodifiable(
         (integrityIssues.toSet().toList()..sort()),
       );

  final TissueWaterNoiseAnalysis analysis;
  final List<String> integrityIssues;

  bool get canProceed => analysis.canProceed && integrityIssues.isEmpty;

  TissueWaterNoiseAnalysis? get acceptedAnalysis =>
      canProceed ? analysis : null;
}

/// Deterministic local isolation of observed scale change into a caller-
/// supported tissue component and the residual water/noise component.
///
/// The engine never invents a tissue estimate. The caller must supply a
/// supported tissue-change estimate and its evidence identifiers. When that
/// evidence is absent, stale, or incompatible with accepted AI Context, the
/// engine exposes insufficiency instead of false precision.
final class TissueWaterNoiseEngine {
  const TissueWaterNoiseEngine({
    this.integrityValidator = const TissueWaterNoiseIntegrityValidator(),
  });

  final TissueWaterNoiseIntegrityValidator integrityValidator;

  TissueWaterNoiseEngineResult analyze<T>({
    required AiContextEngineResult<T> contextResult,
    required TissueWaterNoisePolicy policy,
    required double? supportedTissueChangeKg,
    Iterable<String> tissueEvidenceIds = const <String>[],
    Iterable<String> waterSignalEvidenceIds = const <String>[],
    double evidenceConfidence = 1,
  }) {
    policy.validate();
    if (evidenceConfidence < 0 || evidenceConfidence > 1) {
      throw ArgumentError.value(
        evidenceConfidence,
        'evidenceConfidence',
        'must be in [0, 1]',
      );
    }

    final context = contextResult.acceptedContext;
    if (context == null) {
      return _validated(
        TissueWaterNoiseAnalysis(
          classification: TissueWaterNoiseClassification.rejected,
          observedChangeKg: null,
          supportedTissueChangeKg: supportedTissueChangeKg,
          isolatedWaterNoiseKg: null,
          confidence: 0,
          evidenceIds: const <String>[],
          uncertaintyReasons: const <String>['AI Context is not accepted'],
          alternativeExplanations: const <String>[],
        ),
      );
    }

    final trend = context.bodyTrends?.trendFor(policy.weightMetricKey);
    if (trend == null ||
        trend.observations.length < policy.minimumObservations) {
      return _insufficient(
        'insufficient accepted weight observations',
        supportedTissueChangeKg,
      );
    }

    final latest = trend.observations.last;
    final previous = trend.observations[trend.observations.length - 2];
    final gap = latest.observedAt.toUtc().difference(
      previous.observedAt.toUtc(),
    );
    if (gap <= Duration.zero || gap > policy.maximumSupportedGap) {
      return _insufficient(
        'observation interval is outside caller-owned policy',
        supportedTissueChangeKg,
      );
    }

    final normalizedTissueEvidence = tissueEvidenceIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (supportedTissueChangeKg == null || normalizedTissueEvidence.isEmpty) {
      return _insufficient(
        'supported tissue-change evidence is missing',
        supportedTissueChangeKg,
      );
    }

    final observedChange = latest.value - previous.value;
    final waterNoise = observedChange - supportedTissueChangeKg;
    final tissueMagnitude = supportedTissueChangeKg.abs();
    final waterMagnitude = waterNoise.abs();
    final difference = (tissueMagnitude - waterMagnitude).abs();

    final classification = difference <= policy.dominanceToleranceKg
        ? TissueWaterNoiseClassification.mixed
        : tissueMagnitude > waterMagnitude
        ? TissueWaterNoiseClassification.tissueDominant
        : TissueWaterNoiseClassification.waterDominant;

    final waterEvidence = waterSignalEvidenceIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final evidenceIds = <String>{
      '${policy.weightMetricKey}:${previous.observedAt.toUtc().toIso8601String()}',
      '${policy.weightMetricKey}:${latest.observedAt.toUtc().toIso8601String()}',
      ...normalizedTissueEvidence,
      ...waterEvidence,
    };
    final uncertainty = <String>[
      if (waterEvidence.isEmpty)
        'residual water/noise component has no direct supporting signal',
    ];
    final alternatives = <String>[
      if (waterEvidence.isEmpty) 'measurement variability',
      'unmodeled intake, glycogen, sodium, hydration, or gastrointestinal mass',
    ];
    final confidence = waterEvidence.isEmpty
        ? evidenceConfidence * 0.75
        : evidenceConfidence;

    return _validated(
      TissueWaterNoiseAnalysis(
        classification: classification,
        observedChangeKg: observedChange,
        supportedTissueChangeKg: supportedTissueChangeKg,
        isolatedWaterNoiseKg: waterNoise,
        confidence: confidence,
        evidenceIds: evidenceIds,
        uncertaintyReasons: uncertainty,
        alternativeExplanations: alternatives,
      ),
    );
  }

  TissueWaterNoiseEngineResult _insufficient(
    String reason,
    double? supportedTissueChangeKg,
  ) {
    return _validated(
      TissueWaterNoiseAnalysis(
        classification: TissueWaterNoiseClassification.insufficientEvidence,
        observedChangeKg: null,
        supportedTissueChangeKg: supportedTissueChangeKg,
        isolatedWaterNoiseKg: null,
        confidence: 0,
        evidenceIds: const <String>[],
        uncertaintyReasons: <String>[reason],
        alternativeExplanations: const <String>[],
      ),
    );
  }

  TissueWaterNoiseEngineResult _validated(TissueWaterNoiseAnalysis analysis) {
    return TissueWaterNoiseEngineResult(
      analysis: analysis,
      integrityIssues: integrityValidator.validate(analysis),
    );
  }
}
