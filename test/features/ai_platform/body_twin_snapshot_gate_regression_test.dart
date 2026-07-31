import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_metric_provenance.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_snapshot.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gate is deterministic and does not mutate caller provenance', () {
    const gate = BodyTwinSnapshotGate();
    final observation = BodyTwinObservation(
      metricKey: 'waist_cm',
      value: 104,
      unit: 'cm',
      observedAt: DateTime.utc(2026, 7, 23),
      source: 'measurement_log',
      reliability: 0.9,
    );
    final snapshot = BodyTwinSnapshot(
      asOf: DateTime.utc(2026, 7, 24),
      observationsByMetric: {'waist_cm': observation},
      requiredMetricKeys: const ['waist_cm'],
    );
    final provenance = <String, BodyTwinMetricProvenance>{
      'waist_cm': BodyTwinMetricProvenance.fromObservation(observation),
    };

    final first = gate.evaluate(
      snapshot: snapshot,
      provenanceByMetric: provenance,
    );
    final second = gate.evaluate(
      snapshot: snapshot,
      provenanceByMetric: provenance,
    );

    expect(first.canProceed, second.canProceed);
    expect(first.integrity.issues, isEmpty);
    expect(second.integrity.issues, isEmpty);
    expect(provenance.keys, ['waist_cm']);
    expect(
      () => first.provenanceByMetric['weight_kg'] =
          BodyTwinMetricProvenance.fromObservation(observation),
      throwsUnsupportedError,
    );
  });
}
