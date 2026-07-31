import '../domain/body_twin_consistency_result.dart';
import '../domain/body_twin_engine_result.dart';
import '../domain/body_twin_freshness_result.dart';
import '../domain/body_twin_observation.dart';
import 'body_twin_engine_integrity_validator.dart';
import 'body_twin_foundation_facade.dart';
import 'body_twin_trend_state_builder.dart';

/// Complete offline composition root for the deterministic Body Twin Engine.
///
/// It composes the accepted snapshot trust chain with trend-ready factual
/// history and validates their closure invariants. It performs no prediction,
/// interpolation, persistence, provider access, recommendation, diagnosis, or
/// medical interpretation.
final class BodyTwinEngine {
  const BodyTwinEngine({
    this.facade = const BodyTwinFoundationFacade(),
    this.trendBuilder = const BodyTwinTrendStateBuilder(),
    this.integrityValidator = const BodyTwinEngineIntegrityValidator(),
  });

  final BodyTwinFoundationFacade facade;
  final BodyTwinTrendStateBuilder trendBuilder;
  final BodyTwinEngineIntegrityValidator integrityValidator;

  BodyTwinEngineResult build({
    required DateTime asOf,
    required Iterable<BodyTwinObservation> observations,
    required BodyTwinFreshnessPolicy freshnessPolicy,
    required BodyTwinConsistencyPolicy consistencyPolicy,
    Iterable<String> requiredMetricKeys = const <String>[],
  }) {
    final immutableObservations = List<BodyTwinObservation>.unmodifiable(
      observations,
    );
    final outcome = facade.build(
      asOf: asOf,
      observations: immutableObservations,
      freshnessPolicy: freshnessPolicy,
      consistencyPolicy: consistencyPolicy,
      requiredMetricKeys: requiredMetricKeys,
    );
    final trendState = trendBuilder.build(
      asOf: asOf,
      observations: immutableObservations,
    );
    return BodyTwinEngineResult(
      outcome: outcome,
      trendState: trendState,
      integrityIssues: integrityValidator.validate(
        outcome: outcome,
        trendState: trendState,
      ),
    );
  }
}
