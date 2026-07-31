import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_consistency_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_outcome.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_foundation_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not expose stale or inconsistent snapshots', () {
    const facade = BodyTwinFoundationFacade();
    final asOf = DateTime.utc(2026, 7, 24, 12);
    final observation = BodyTwinObservation(
      metricKey: 'weight',
      value: 95.1,
      unit: 'lb',
      observedAt: asOf.subtract(const Duration(days: 3)),
      source: 'local-log',
    );

    final result = facade.build(
      asOf: asOf,
      observations: [observation],
      freshnessPolicy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: {'weight': const Duration(days: 1)},
      ),
      consistencyPolicy: BodyTwinConsistencyPolicy(
        rulesByMetric: {
          'weight': BodyTwinMetricConsistencyRule(expectedUnit: 'kg'),
        },
      ),
      requiredMetricKeys: const ['weight'],
    );

    expect(result.status, BodyTwinOutcomeStatus.rejected);
    expect(result.canProceed, isFalse);
    expect(result.acceptedSnapshot, isNull);
    expect(result.trustedResult.freshnessResult.staleMetricKeys, ['weight']);
  });
}
