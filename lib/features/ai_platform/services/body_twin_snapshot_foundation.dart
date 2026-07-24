import '../domain/body_twin_foundation_result.dart';
import '../domain/body_twin_observation.dart';
import 'body_twin_foundation.dart';
import 'body_twin_snapshot_gate.dart';

/// Stable public facade for deterministic local Body Twin snapshot assembly.
///
/// The facade delegates state assembly to [BodyTwinFoundation] and integrity
/// enforcement to [BodyTwinSnapshotGate]. It adds no inference, repair,
/// freshness policy, persistence, network/provider access, recommendation,
/// medical interpretation, clock access, randomness, or feature mutation.
final class BodyTwinSnapshotFoundation {
  const BodyTwinSnapshotFoundation({
    this.builder = const BodyTwinFoundation(),
    this.gate = const BodyTwinSnapshotGate(),
  });

  final BodyTwinFoundation builder;
  final BodyTwinSnapshotGate gate;

  BodyTwinFoundationResult build({
    required DateTime asOf,
    required Iterable<BodyTwinObservation> observations,
    Iterable<String> requiredMetricKeys = const <String>[],
  }) {
    final snapshot = builder.build(
      asOf: asOf,
      observations: observations,
      requiredMetricKeys: requiredMetricKeys,
    );
    return BodyTwinFoundationResult.fromGate(
      gate.evaluateProjected(snapshot),
    );
  }
}
