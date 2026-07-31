import '../domain/adaptive_metabolic_forecast.dart';
import '../domain/adaptive_metabolic_forecast_policy.dart';
import '../domain/ai_context.dart';
import 'adaptive_metabolic_forecast_integrity_validator.dart';
import 'tissue_water_noise_engine.dart';

/// Deterministic local forecasting boundary.
///
/// The engine projects only caller-supported energy balance and an already
/// accepted tissue/water analysis. It does not estimate expenditure, infer a
/// deficit, diagnose metabolism, or hide uncertainty.
final class AdaptiveMetabolicForecastEngine {
  const AdaptiveMetabolicForecastEngine({
    this.integrityValidator =
        const AdaptiveMetabolicForecastIntegrityValidator(),
  });

  final AdaptiveMetabolicForecastIntegrityValidator integrityValidator;

  AdaptiveMetabolicForecastResult forecast<T>({
    required AiContextEngineResult<T> contextResult,
    required TissueWaterNoiseEngineResult noiseResult,
    required AdaptiveMetabolicForecastPolicy policy,
    required double? supportedDailyEnergyBalanceKcal,
    required double energyEvidenceConfidence,
    Iterable<String> energyEvidenceIds = const <String>[],
    Iterable<String> assumptionIds = const <String>[],
  }) {
    policy.validate();
    if (energyEvidenceConfidence < 0 || energyEvidenceConfidence > 1) {
      throw ArgumentError.value(
        energyEvidenceConfidence,
        'energyEvidenceConfidence',
        'must be in [0, 1]',
      );
    }
    final context = contextResult.acceptedContext;
    final noise = noiseResult.acceptedAnalysis;
    if (context == null || noise == null) {
      return _result(
        AdaptiveMetabolicForecast(
          status: AdaptiveMetabolicForecastStatus.rejected,
          asOf: contextResult.context.asOf,
          points: const <AdaptiveMetabolicForecastPoint>[],
          assumptionIds: const <String>[],
          evidenceIds: const <String>[],
          uncertaintyReasons: const <String>[
            'accepted AI Context and tissue/water analysis are required',
          ],
        ),
      );
    }
    final evidence = energyEvidenceIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final assumptions = assumptionIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (supportedDailyEnergyBalanceKcal == null ||
        evidence.isEmpty ||
        assumptions.isEmpty) {
      return _abstain(
        context.asOf,
        'supported energy balance, evidence, and assumptions are required',
      );
    }
    final confidence = energyEvidenceConfidence < noise.confidence
        ? energyEvidenceConfidence
        : noise.confidence;
    if (confidence < policy.minimumConfidence) {
      return _abstain(
        context.asOf,
        'combined evidence confidence is below caller-owned policy',
      );
    }
    final horizons = policy.horizons.toList()..sort();
    final points = horizons.map((horizon) {
      final tissueChange =
          supportedDailyEnergyBalanceKcal *
          horizon.inHours /
          24 /
          policy.kcalPerKgTissue;
      final scaleChange = tissueChange + (noise.isolatedWaterNoiseKg ?? 0);
      return AdaptiveMetabolicForecastPoint(
        horizon: horizon,
        projectedTissueChangeKg: tissueChange,
        projectedScaleChangeKg: scaleChange,
        confidence: confidence,
      );
    });
    return _result(
      AdaptiveMetabolicForecast(
        status: AdaptiveMetabolicForecastStatus.accepted,
        asOf: context.asOf,
        points: points,
        assumptionIds: assumptions,
        evidenceIds: <String>{...evidence, ...noise.evidenceIds},
        uncertaintyReasons: noise.uncertaintyReasons,
      ),
    );
  }

  AdaptiveMetabolicForecastResult _abstain(DateTime asOf, String reason) =>
      _result(
        AdaptiveMetabolicForecast(
          status: AdaptiveMetabolicForecastStatus.abstained,
          asOf: asOf,
          points: const <AdaptiveMetabolicForecastPoint>[],
          assumptionIds: const <String>[],
          evidenceIds: const <String>[],
          uncertaintyReasons: <String>[reason],
        ),
      );

  AdaptiveMetabolicForecastResult _result(AdaptiveMetabolicForecast forecast) =>
      AdaptiveMetabolicForecastResult(
        forecast: forecast,
        integrityIssues: integrityValidator.validate(forecast),
      );
}
