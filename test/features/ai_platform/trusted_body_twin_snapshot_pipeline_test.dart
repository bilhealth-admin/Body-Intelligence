import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_consistency_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/trusted_body_twin_snapshot_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final asOf = DateTime.utc(2026, 7, 24, 12);
  final freshnessPolicy = BodyTwinFreshnessPolicy(
    maxAgeByMetric: {'weight': const Duration(days: 1)},
  );
  final consistencyPolicy = BodyTwinConsistencyPolicy(
    rulesByMetric: {
      'weight': BodyTwinMetricConsistencyRule(
        expectedUnit: 'kg',
        minimum: 30,
        maximum: 300,
      ),
    },
  );

  test('returns one accepted snapshot after every local gate passes', () {
    final result = const TrustedBodyTwinSnapshotPipeline().build(
      asOf: asOf,
      observations: [
        BodyTwinObservation(
          metricKey: 'weight',
          value: 95,
          unit: 'kg',
          observedAt: asOf.subtract(const Duration(hours: 1)),
          source: 'local-log',
        ),
      ],
      requiredMetricKeys: const ['weight'],
      freshnessPolicy: freshnessPolicy,
      consistencyPolicy: consistencyPolicy,
    );

    expect(result.foundationResult.isAccepted, isTrue);
    expect(result.freshnessResult.canProceed, isTrue);
    expect(result.consistencyResult.canProceed, isTrue);
    expect(result.canProceed, isTrue);
    expect(result.acceptedSnapshot!.observationsByMetric.keys, ['weight']);
  });

  test('preserves explainable consistency rejection', () {
    final result = const TrustedBodyTwinSnapshotPipeline().build(
      asOf: asOf,
      observations: [
        BodyTwinObservation(
          metricKey: 'weight',
          value: 95,
          unit: 'lb',
          observedAt: asOf.subtract(const Duration(hours: 1)),
          source: 'local-log',
        ),
      ],
      requiredMetricKeys: const ['weight'],
      freshnessPolicy: freshnessPolicy,
      consistencyPolicy: consistencyPolicy,
    );

    expect(result.canProceed, isFalse);
    expect(result.acceptedSnapshot, isNull);
    expect(
      result.consistencyResult.assessmentsByMetric['weight']!.status,
      BodyTwinMetricConsistencyStatus.unitMismatch,
    );
  });
}
