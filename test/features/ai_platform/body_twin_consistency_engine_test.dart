import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_consistency_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_consistency_engine.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_freshness_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_snapshot_foundation.dart';

void main() {
  final asOf = DateTime.utc(2026, 7, 24, 12);

  BodyTwinFreshnessResult freshResult({double value = 95, String unit = 'kg'}) {
    final foundation = const BodyTwinSnapshotFoundation().build(
      asOf: asOf,
      observations: [
        BodyTwinObservation(
          metricKey: 'weight',
          value: value,
          unit: unit,
          observedAt: asOf.subtract(const Duration(hours: 1)),
          source: 'local-log',
        ),
      ],
    );
    return const BodyTwinFreshnessGate().evaluate(
      foundationResult: foundation,
      policy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: {'weight': Duration(days: 1)},
      ),
    );
  }

  test('accepts a configured metric within exact unit and bounds', () {
    final result = const BodyTwinConsistencyEngine().evaluate(
      freshnessResult: freshResult(),
      policy: BodyTwinConsistencyPolicy(
        rulesByMetric: {
          'weight': BodyTwinMetricConsistencyRule(
            expectedUnit: 'kg',
            minimum: 30,
            maximum: 300,
          ),
        },
      ),
    );

    expect(result.canProceed, isTrue);
    expect(result.acceptedConsistentSnapshot, isNotNull);
    expect(
      result.assessmentsByMetric['weight']!.status,
      BodyTwinMetricConsistencyStatus.consistent,
    );
  });

  test('rejects unit mismatch without converting or repairing', () {
    final result = const BodyTwinConsistencyEngine().evaluate(
      freshnessResult: freshResult(unit: 'lb'),
      policy: BodyTwinConsistencyPolicy(
        rulesByMetric: {
          'weight': BodyTwinMetricConsistencyRule(expectedUnit: 'kg'),
        },
      ),
    );

    expect(result.canProceed, isFalse);
    expect(result.acceptedConsistentSnapshot, isNull);
    expect(
      result.assessmentsByMetric['weight']!.status,
      BodyTwinMetricConsistencyStatus.unitMismatch,
    );
  });

  test('rejects values below or above caller-owned bounds', () {
    final policy = BodyTwinConsistencyPolicy(
      rulesByMetric: {
        'weight': BodyTwinMetricConsistencyRule(
          expectedUnit: 'kg',
          minimum: 30,
          maximum: 300,
        ),
      },
    );

    final below = const BodyTwinConsistencyEngine().evaluate(
      freshnessResult: freshResult(value: 29),
      policy: policy,
    );
    final above = const BodyTwinConsistencyEngine().evaluate(
      freshnessResult: freshResult(value: 301),
      policy: policy,
    );

    expect(
      below.assessmentsByMetric['weight']!.status,
      BodyTwinMetricConsistencyStatus.belowMinimum,
    );
    expect(
      above.assessmentsByMetric['weight']!.status,
      BodyTwinMetricConsistencyStatus.aboveMaximum,
    );
  });

  test('unconfigured metrics remain explicit and block consumption', () {
    final result = const BodyTwinConsistencyEngine().evaluate(
      freshnessResult: freshResult(),
      policy: BodyTwinConsistencyPolicy(rulesByMetric: const {}),
    );

    expect(result.inconsistentMetricKeys, ['weight']);
    expect(
      result.assessmentsByMetric['weight']!.status,
      BodyTwinMetricConsistencyStatus.unconfigured,
    );
  });
}
