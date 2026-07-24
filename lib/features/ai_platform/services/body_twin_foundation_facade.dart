import '../domain/body_twin_consistency_result.dart';
import '../domain/body_twin_freshness_result.dart';
import '../domain/body_twin_observation.dart';
import '../domain/body_twin_outcome.dart';
import 'trusted_body_twin_snapshot_pipeline.dart';

/// Stable public facade over the complete deterministic local Body Twin trust
/// pipeline.
///
/// The facade adds no persistence, network/provider access, unit conversion,
/// prediction, recommendation, medical inference, clock access, randomness, or
/// feature mutation. Caller-owned policies and the explicit [asOf] instant are
/// passed unchanged to the established pipeline.
final class BodyTwinFoundationFacade {
  const BodyTwinFoundationFacade({
    this.pipeline = const TrustedBodyTwinSnapshotPipeline(),
  });

  final TrustedBodyTwinSnapshotPipeline pipeline;

  BodyTwinOutcome build({
    required DateTime asOf,
    required Iterable<BodyTwinObservation> observations,
    required BodyTwinFreshnessPolicy freshnessPolicy,
    required BodyTwinConsistencyPolicy consistencyPolicy,
    Iterable<String> requiredMetricKeys = const <String>[],
  }) {
    return BodyTwinOutcome.fromTrustedResult(
      pipeline.build(
        asOf: asOf,
        observations: observations,
        freshnessPolicy: freshnessPolicy,
        consistencyPolicy: consistencyPolicy,
        requiredMetricKeys: requiredMetricKeys,
      ),
    );
  }
}
