import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_metric_provenance.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_snapshot.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_snapshot_gate_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_snapshot_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gate = BodyTwinSnapshotGate();
  final observation = BodyTwinObservation(
    metricKey: 'weight_kg',
    value: 95.1,
    unit: 'kg',
    observedAt: DateTime.utc(2026, 7, 24, 2),
    source: 'weight_log',
    reliability: 0.95,
  );
  final snapshot = BodyTwinSnapshot(
    asOf: DateTime.utc(2026, 7, 24, 3),
    observationsByMetric: {'weight_kg': observation},
    requiredMetricKeys: const ['weight_kg'],
  );

  test('accepts a projected provenance envelope for consumption', () {
    final result = gate.evaluateProjected(snapshot);

    expect(result.status, BodyTwinSnapshotGateStatus.accepted);
    expect(result.canProceed, isTrue);
    expect(result.isRejected, isFalse);
    expect(identical(result.acceptedSnapshot, snapshot), isTrue);
    expect(
      result.acceptedProvenanceByMetric!['weight_kg']!.source,
      'weight_log',
    );
    expect(result.integrity.isValid, isTrue);
  });

  test('rejects inconsistent provenance without exposing accepted values', () {
    final result = gate.evaluate(
      snapshot: snapshot,
      provenanceByMetric: {
        'weight_kg': BodyTwinMetricProvenance(
          metricKey: 'weight_kg',
          source: 'manual_override',
          observedAt: observation.observedAt,
          reliability: observation.reliability,
        ),
      },
    );

    expect(result.status, BodyTwinSnapshotGateStatus.rejected);
    expect(result.canProceed, isFalse);
    expect(result.isRejected, isTrue);
    expect(result.acceptedSnapshot, isNull);
    expect(result.acceptedProvenanceByMetric, isNull);
    expect(
      result.integrity.issues.single.code,
      BodyTwinSnapshotIntegrityIssueCode.provenanceSourceMismatch,
    );
    expect(identical(result.snapshot, snapshot), isTrue);
  });
}
