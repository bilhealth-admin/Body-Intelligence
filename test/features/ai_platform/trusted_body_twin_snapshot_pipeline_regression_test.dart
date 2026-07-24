import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_consistency_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/trusted_body_twin_snapshot_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not bypass missing-required-metric or stale-data gates', () {
    final asOf = DateTime.utc(2026, 7, 24, 12);
    final pipeline = const TrustedBodyTwinSnapshotPipeline();
    final policy = BodyTwinConsistencyPolicy(
      rulesByMetric: {
        'weight': BodyTwinMetricConsistencyRule(expectedUnit: 'kg'),
      },
    );

    final missing = pipeline.build(
      asOf: asOf,
      observations: const [],
      requiredMetricKeys: const ['weight'],
      freshnessPolicy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: {'weight': const Duration(days: 1)},
      ),
      consistencyPolicy: policy,
    );
    expect(missing.foundationResult.isAccepted, isTrue);
    expect(missing.canProceed, isFalse);
    expect(missing.acceptedSnapshot, isNull);

    final stale = pipeline.build(
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
      requiredMetricKeys: const ['weight'],
      freshnessPolicy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: {'weight': const Duration(days: 1)},
      ),
      consistencyPolicy: policy,
    );
    expect(stale.freshnessResult.canProceed, isFalse);
    expect(stale.consistencyResult.assessmentsByMetric, isEmpty);
    expect(stale.canProceed, isFalse);
  });
}
