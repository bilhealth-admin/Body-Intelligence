import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_metric_provenance.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_snapshot.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_snapshot_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('issues are stable and sorted independent of map insertion order', () {
    const validator = BodyTwinSnapshotValidator();
    final snapshot = BodyTwinSnapshot(
      asOf: DateTime.utc(2026, 7, 24),
      observationsByMetric: {
        'z': BodyTwinObservation(
          metricKey: 'z',
          value: 1,
          unit: 'u',
          observedAt: DateTime.utc(2026, 7, 23),
          source: 'local',
        ),
      },
      requiredMetricKeys: const [],
    );

    final result = validator.validate(
      snapshot: snapshot,
      provenanceByMetric: {
        'orphan': BodyTwinMetricProvenance(
          metricKey: 'orphan',
          source: 'local',
          observedAt: DateTime.utc(2026, 7, 23),
          reliability: 1,
        ),
      },
    );

    expect(result.isValid, isFalse);
    expect(result.issues, hasLength(1));
    expect(
      result.issues.single.code,
      BodyTwinSnapshotIntegrityIssueCode.provenanceMetricKeyMismatch,
    );
    expect(result.issues.single.metricKey, 'orphan');
    expect(
      () => result.issues.add(result.issues.single),
      throwsUnsupportedError,
    );
  });
}
