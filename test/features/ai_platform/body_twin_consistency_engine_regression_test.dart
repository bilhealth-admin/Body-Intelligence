import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_consistency_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_consistency_engine.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_freshness_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_foundation.dart';

void main() {
  test('preserves upstream freshness rejection and emits no assessments', () {
    final asOf = DateTime.utc(2026, 7, 24);
    final foundation = const BodyTwinSnapshotFoundation().build(
      asOf: asOf,
      observations: [
        BodyTwinObservation(
          metricKey: 'weight',
          value: 95,
          unit: 'kg',
          observedAt: asOf.subtract(const Duration(days: 2)),
          source: 'local-log',
        ),
      ],
    );
    final freshness = const BodyTwinFreshnessGate().evaluate(
      foundationResult: foundation,
      policy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: {'weight': Duration(days: 1)},
      ),
    );

    final result = const BodyTwinConsistencyEngine().evaluate(
      freshnessResult: freshness,
      policy: BodyTwinConsistencyPolicy(
        rulesByMetric: {
          'weight': BodyTwinMetricConsistencyRule(expectedUnit: 'kg'),
        },
      ),
    );

    expect(result.upstreamAccepted, isFalse);
    expect(result.assessmentsByMetric, isEmpty);
    expect(result.canProceed, isFalse);
    expect(result.acceptedConsistentSnapshot, isNull);
  });

  test('policy rejects invalid bounds and blank units', () {
    expect(
      () => BodyTwinMetricConsistencyRule(expectedUnit: ' '),
      throwsArgumentError,
    );
    expect(
      () => BodyTwinMetricConsistencyRule(
        expectedUnit: 'kg',
        minimum: 10,
        maximum: 5,
      ),
      throwsArgumentError,
    );
  });
}
