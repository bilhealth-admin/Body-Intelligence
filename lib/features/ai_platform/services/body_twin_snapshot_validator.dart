import '../domain/body_twin_metric_provenance.dart';
import '../domain/body_twin_snapshot.dart';
import '../domain/body_twin_snapshot_integrity_result.dart';

/// Pure local validator for Body Twin snapshot and provenance consistency.
///
/// It performs no estimation, correction, persistence, provider access,
/// recommendation ranking, medical inference, or clock access.
final class BodyTwinSnapshotValidator {
  const BodyTwinSnapshotValidator();

  BodyTwinSnapshotIntegrityResult validate({
    required BodyTwinSnapshot snapshot,
    required Map<String, BodyTwinMetricProvenance> provenanceByMetric,
  }) {
    final issues = <BodyTwinSnapshotIntegrityIssue>[];

    for (final entry in snapshot.observationsByMetric.entries) {
      final metricKey = entry.key;
      final observation = entry.value;
      final provenance = provenanceByMetric[metricKey];

      if (metricKey != observation.metricKey) {
        issues.add(
          BodyTwinSnapshotIntegrityIssue(
            code: BodyTwinSnapshotIntegrityIssueCode.metricKeyMismatch,
            metricKey: metricKey,
            message: 'Snapshot map key does not match observation metric key.',
          ),
        );
      }
      if (observation.observedAt.isAfter(snapshot.asOf)) {
        issues.add(
          BodyTwinSnapshotIntegrityIssue(
            code: BodyTwinSnapshotIntegrityIssueCode.futureObservation,
            metricKey: metricKey,
            message: 'Observation occurs after the snapshot as-of time.',
          ),
        );
      }
      if (provenance == null) {
        continue;
      }
      if (provenance.metricKey != observation.metricKey) {
        issues.add(
          BodyTwinSnapshotIntegrityIssue(
            code: BodyTwinSnapshotIntegrityIssueCode.provenanceMetricKeyMismatch,
            metricKey: metricKey,
            message: 'Provenance metric key does not match the observation.',
          ),
        );
      }
      if (provenance.source != observation.source) {
        issues.add(
          BodyTwinSnapshotIntegrityIssue(
            code: BodyTwinSnapshotIntegrityIssueCode.provenanceSourceMismatch,
            metricKey: metricKey,
            message: 'Provenance source does not match the observation.',
          ),
        );
      }
      if (!provenance.observedAt.isAtSameMomentAs(observation.observedAt)) {
        issues.add(
          BodyTwinSnapshotIntegrityIssue(
            code: BodyTwinSnapshotIntegrityIssueCode.provenanceObservedAtMismatch,
            metricKey: metricKey,
            message: 'Provenance timestamp does not match the observation.',
          ),
        );
      }
      if (provenance.reliability != observation.reliability) {
        issues.add(
          BodyTwinSnapshotIntegrityIssue(
            code: BodyTwinSnapshotIntegrityIssueCode.provenanceReliabilityMismatch,
            metricKey: metricKey,
            message: 'Provenance reliability does not match the observation.',
          ),
        );
      }
    }

    for (final metricKey in provenanceByMetric.keys) {
      if (!snapshot.observationsByMetric.containsKey(metricKey)) {
        issues.add(
          BodyTwinSnapshotIntegrityIssue(
            code: BodyTwinSnapshotIntegrityIssueCode.provenanceMetricKeyMismatch,
            metricKey: metricKey,
            message: 'Provenance exists for a metric absent from the snapshot.',
          ),
        );
      }
    }

    issues.sort((left, right) {
      final metricOrder = left.metricKey.compareTo(right.metricKey);
      return metricOrder != 0
          ? metricOrder
          : left.code.name.compareTo(right.code.name);
    });
    return BodyTwinSnapshotIntegrityResult(issues: issues);
  }

  Map<String, BodyTwinMetricProvenance> projectProvenance(
    BodyTwinSnapshot snapshot,
  ) {
    return Map<String, BodyTwinMetricProvenance>.unmodifiable({
      for (final entry in snapshot.observationsByMetric.entries)
        entry.key: BodyTwinMetricProvenance.fromObservation(entry.value),
    });
  }
}
