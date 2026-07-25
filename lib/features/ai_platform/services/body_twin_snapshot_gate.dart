import '../domain/body_twin_metric_provenance.dart';
import '../domain/body_twin_snapshot.dart';
import '../domain/body_twin_snapshot_gate_result.dart';
import 'body_twin_snapshot_validator.dart';

/// Pure local gate over the established Body Twin snapshot validator.
///
/// This service adds no estimation, repair, freshness policy, persistence,
/// provider access, recommendation ranking, medical inference, or clock access.
final class BodyTwinSnapshotGate {
  const BodyTwinSnapshotGate({
    this.validator = const BodyTwinSnapshotValidator(),
  });

  final BodyTwinSnapshotValidator validator;

  BodyTwinSnapshotGateResult evaluate({
    required BodyTwinSnapshot snapshot,
    required Map<String, BodyTwinMetricProvenance> provenanceByMetric,
  }) {
    final immutableProvenance =
        Map<String, BodyTwinMetricProvenance>.unmodifiable(provenanceByMetric);
    return BodyTwinSnapshotGateResult.from(
      snapshot: snapshot,
      provenanceByMetric: immutableProvenance,
      integrity: validator.validate(
        snapshot: snapshot,
        provenanceByMetric: immutableProvenance,
      ),
    );
  }

  BodyTwinSnapshotGateResult evaluateProjected(BodyTwinSnapshot snapshot) {
    return evaluate(
      snapshot: snapshot,
      provenanceByMetric: validator.projectProvenance(snapshot),
    );
  }
}
