import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_metric_provenance.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_snapshot.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_snapshot_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = BodyTwinSnapshotValidator();
  final asOf = DateTime.utc(2026, 7, 24, 3);
  final observation = BodyTwinObservation(
    metricKey: 'weight_kg',
    value: 95.1,
    unit: 'kg',
    observedAt: DateTime.utc(2026, 7, 24, 2),
    source: 'weight_log',
    reliability: 0.95,
  );

  test('projected provenance validates without issues', () {
    final snapshot = BodyTwinSnapshot(
      asOf: asOf,
      observationsByMetric: {'weight_kg': observation},
      requiredMetricKeys: const ['weight_kg'],
    );
    final provenance = validator.projectProvenance(snapshot);
    final result = validator.validate(
      snapshot: snapshot,
      provenanceByMetric: provenance,
    );

    expect(result.isValid, isTrue);
    expect(provenance['weight_kg']!.source, 'weight_log');
    expect(provenance['weight_kg']!.reliability, 0.95);
  });

  test('reports deterministic snapshot and provenance mismatches', () {
    final snapshot = BodyTwinSnapshot(
      asOf: asOf,
      observationsByMetric: {
        'weight': BodyTwinObservation(
          metricKey: 'weight_kg',
          value: 95.1,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 24, 4),
          source: 'weight_log',
          reliability: 0.95,
        ),
      },
      requiredMetricKeys: const [],
    );
    final result = validator.validate(
      snapshot: snapshot,
      provenanceByMetric: {
        'weight': BodyTwinMetricProvenance(
          metricKey: 'mass_kg',
          source: 'manual',
          observedAt: DateTime.utc(2026, 7, 24, 1),
          reliability: 0.5,
        ),
      },
    );

    expect(
      result.issues.map((issue) => issue.code),
      containsAll(<BodyTwinSnapshotIntegrityIssueCode>[
        BodyTwinSnapshotIntegrityIssueCode.metricKeyMismatch,
        BodyTwinSnapshotIntegrityIssueCode.futureObservation,
        BodyTwinSnapshotIntegrityIssueCode.provenanceMetricKeyMismatch,
        BodyTwinSnapshotIntegrityIssueCode.provenanceSourceMismatch,
        BodyTwinSnapshotIntegrityIssueCode.provenanceObservedAtMismatch,
        BodyTwinSnapshotIntegrityIssueCode.provenanceReliabilityMismatch,
      ]),
    );
  });
}
