import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_consistency_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_outcome.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_foundation_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const facade = BodyTwinFoundationFacade();
  final asOf = DateTime.utc(2026, 7, 24, 12);
  final freshness = BodyTwinFreshnessPolicy(
    maxAgeByMetric: {'weight': const Duration(days: 2)},
  );
  final consistency = BodyTwinConsistencyPolicy(
    rulesByMetric: {
      'weight': BodyTwinMetricConsistencyRule(
        expectedUnit: 'kg',
        minimum: 20,
        maximum: 400,
      ),
    },
  );

  test('exposes accepted snapshot only when every trust gate passes', () {
    final result = facade.build(
      asOf: asOf,
      observations: [
        BodyTwinObservation(
          metricKey: 'weight',
          value: 95.1,
          unit: 'kg',
          observedAt: asOf.subtract(const Duration(hours: 2)),
          source: 'local-log',
        ),
      ],
      freshnessPolicy: freshness,
      consistencyPolicy: consistency,
      requiredMetricKeys: const ['weight'],
    );

    expect(result.status, BodyTwinOutcomeStatus.accepted);
    expect(result.canProceed, isTrue);
    expect(result.acceptedSnapshot?.observationFor('weight')?.value, 95.1);
  });

  test('classifies structurally accepted incomplete snapshot explicitly', () {
    final result = facade.build(
      asOf: asOf,
      observations: const [],
      freshnessPolicy: BodyTwinFreshnessPolicy(maxAgeByMetric: const {}),
      consistencyPolicy: BodyTwinConsistencyPolicy(rulesByMetric: const {}),
      requiredMetricKeys: const ['weight'],
    );

    expect(result.status, BodyTwinOutcomeStatus.incomplete);
    expect(result.canProceed, isFalse);
    expect(result.acceptedSnapshot, isNull);
  });
}
