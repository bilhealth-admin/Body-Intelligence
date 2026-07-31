import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_consistency_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_engine_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closes trusted snapshot and trend state into one accepted result', () {
    final asOf = DateTime.utc(2026, 7, 24, 8);
    final result = const BodyTwinEngine().build(
      asOf: asOf,
      observations: <BodyTwinObservation>[
        BodyTwinObservation(
          metricKey: 'weight',
          value: 95.1,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 24, 7),
          source: 'manual',
        ),
      ],
      freshnessPolicy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: <String, Duration>{'weight': const Duration(hours: 24)},
      ),
      consistencyPolicy: BodyTwinConsistencyPolicy(
        rulesByMetric: <String, BodyTwinMetricConsistencyRule>{
          'weight': BodyTwinMetricConsistencyRule(expectedUnit: 'kg'),
        },
      ),
      requiredMetricKeys: const <String>['weight'],
    );

    expect(result.status, BodyTwinEngineStatus.accepted);
    expect(result.canProceed, isTrue);
    expect(result.integrityIssues, isEmpty);
    expect(result.acceptedSnapshot?.observationFor('weight')?.value, 95.1);
    expect(result.trendState.trendFor('weight')?.observations, hasLength(1));
  });

  test('preserves incomplete outcome and withholds accepted snapshot', () {
    final result = const BodyTwinEngine().build(
      asOf: DateTime.utc(2026, 7, 24, 8),
      observations: const <BodyTwinObservation>[],
      freshnessPolicy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: <String, Duration>{'weight': const Duration(hours: 24)},
      ),
      consistencyPolicy: BodyTwinConsistencyPolicy(
        rulesByMetric: <String, BodyTwinMetricConsistencyRule>{
          'weight': BodyTwinMetricConsistencyRule(expectedUnit: 'kg'),
        },
      ),
      requiredMetricKeys: const <String>['weight'],
    );

    expect(result.status, BodyTwinEngineStatus.incomplete);
    expect(result.canProceed, isFalse);
    expect(result.acceptedSnapshot, isNull);
  });
}
