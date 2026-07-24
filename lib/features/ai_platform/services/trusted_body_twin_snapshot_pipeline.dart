import '../domain/body_twin_consistency_result.dart';
import '../domain/body_twin_freshness_result.dart';
import '../domain/body_twin_observation.dart';
import '../domain/trusted_body_twin_snapshot_result.dart';
import 'body_twin_consistency_engine.dart';
import 'body_twin_freshness_gate.dart';
import 'body_twin_snapshot_foundation.dart';

/// Pure offline composition root for the current Body Twin trust gates.
///
/// The pipeline delegates construction, integrity, freshness, and consistency
/// to the existing deterministic engines. It performs no persistence, network
/// access, provider access, unit conversion, prediction, recommendation, or
/// medical inference.
final class TrustedBodyTwinSnapshotPipeline {
  const TrustedBodyTwinSnapshotPipeline({
    this.foundation = const BodyTwinSnapshotFoundation(),
    this.freshnessGate = const BodyTwinFreshnessGate(),
    this.consistencyEngine = const BodyTwinConsistencyEngine(),
  });

  final BodyTwinSnapshotFoundation foundation;
  final BodyTwinFreshnessGate freshnessGate;
  final BodyTwinConsistencyEngine consistencyEngine;

  TrustedBodyTwinSnapshotResult build({
    required DateTime asOf,
    required Iterable<BodyTwinObservation> observations,
    required BodyTwinFreshnessPolicy freshnessPolicy,
    required BodyTwinConsistencyPolicy consistencyPolicy,
    Iterable<String> requiredMetricKeys = const [],
  }) {
    final foundationResult = foundation.build(
      asOf: asOf,
      observations: observations,
      requiredMetricKeys: requiredMetricKeys,
    );
    final freshnessResult = freshnessGate.evaluate(
      foundationResult: foundationResult,
      policy: freshnessPolicy,
    );
    final consistencyResult = consistencyEngine.evaluate(
      freshnessResult: freshnessResult,
      policy: consistencyPolicy,
    );

    return TrustedBodyTwinSnapshotResult(
      foundationResult: foundationResult,
      freshnessResult: freshnessResult,
      consistencyResult: consistencyResult,
    );
  }
}
