import 'dart:collection';

import 'body_twin_metric_provenance.dart';
import 'body_twin_snapshot.dart';
import 'body_twin_snapshot_integrity_result.dart';

/// Stable outcome of integrity-gating one deterministic Body Twin snapshot.
enum BodyTwinSnapshotGateStatus { accepted, rejected }

/// Immutable consumption boundary for a validated Body Twin snapshot envelope.
///
/// The original snapshot, provenance, and integrity evidence remain inspectable.
/// Consumers may access [acceptedSnapshot] and [acceptedProvenanceByMetric] only
/// when the existing snapshot validator found no issues.
final class BodyTwinSnapshotGateResult {
  BodyTwinSnapshotGateResult._({
    required this.snapshot,
    required Map<String, BodyTwinMetricProvenance> provenanceByMetric,
    required this.integrity,
    required this.status,
  }) : provenanceByMetric = UnmodifiableMapView(
         Map<String, BodyTwinMetricProvenance>.of(provenanceByMetric),
       );

  factory BodyTwinSnapshotGateResult.from({
    required BodyTwinSnapshot snapshot,
    required Map<String, BodyTwinMetricProvenance> provenanceByMetric,
    required BodyTwinSnapshotIntegrityResult integrity,
  }) {
    return BodyTwinSnapshotGateResult._(
      snapshot: snapshot,
      provenanceByMetric: provenanceByMetric,
      integrity: integrity,
      status: integrity.isValid
          ? BodyTwinSnapshotGateStatus.accepted
          : BodyTwinSnapshotGateStatus.rejected,
    );
  }

  final BodyTwinSnapshot snapshot;
  final Map<String, BodyTwinMetricProvenance> provenanceByMetric;
  final BodyTwinSnapshotIntegrityResult integrity;
  final BodyTwinSnapshotGateStatus status;

  bool get canProceed => status == BodyTwinSnapshotGateStatus.accepted;
  bool get isRejected => status == BodyTwinSnapshotGateStatus.rejected;

  BodyTwinSnapshot? get acceptedSnapshot => canProceed ? snapshot : null;

  Map<String, BodyTwinMetricProvenance>? get acceptedProvenanceByMetric =>
      canProceed ? provenanceByMetric : null;
}
