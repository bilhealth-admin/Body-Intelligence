import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_consistency_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_freshness_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is deterministic and does not mutate caller observation order', () {
    final observations = <BodyTwinObservation>[
      BodyTwinObservation(
        metricKey: 'weight',
        value: 96,
        unit: 'kg',
        observedAt: DateTime.utc(2026, 7, 23),
        source: 'manual',
      ),
      BodyTwinObservation(
        metricKey: 'weight',
        value: 95.1,
        unit: 'kg',
        observedAt: DateTime.utc(2026, 7, 24),
        source: 'manual',
      ),
    ];
    final originalFirst = observations.first;
    final engine = const BodyTwinEngine();
    final freshness = BodyTwinFreshnessPolicy(
      maxAgeByMetric: <String, Duration>{'weight': const Duration(days: 3)},
    );
    final consistency = BodyTwinConsistencyPolicy(
      rulesByMetric: <String, BodyTwinMetricConsistencyRule>{
        'weight': BodyTwinMetricConsistencyRule(expectedUnit: 'kg'),
      },
    );

    final first = engine.build(
      asOf: DateTime.utc(2026, 7, 24, 1),
      observations: observations,
      freshnessPolicy: freshness,
      consistencyPolicy: consistency,
      requiredMetricKeys: const <String>['weight'],
    );
    final second = engine.build(
      asOf: DateTime.utc(2026, 7, 24, 1),
      observations: observations.reversed,
      freshnessPolicy: freshness,
      consistencyPolicy: consistency,
      requiredMetricKeys: const <String>['weight'],
    );

    expect(first.canProceed, isTrue);
    expect(second.canProceed, isTrue);
    expect(first.acceptedSnapshot?.observationFor('weight')?.value, 95.1);
    expect(second.acceptedSnapshot?.observationFor('weight')?.value, 95.1);
    expect(observations.first, same(originalFirst));
  });

  test('future observations remain excluded from snapshot and trend state', () {
    final result = const BodyTwinEngine().build(
      asOf: DateTime.utc(2026, 7, 24),
      observations: <BodyTwinObservation>[
        BodyTwinObservation(
          metricKey: 'weight',
          value: 95,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 25),
          source: 'manual',
        ),
      ],
      freshnessPolicy: BodyTwinFreshnessPolicy(
        maxAgeByMetric: <String, Duration>{'weight': const Duration(days: 3)},
      ),
      consistencyPolicy: BodyTwinConsistencyPolicy(
        rulesByMetric: <String, BodyTwinMetricConsistencyRule>{
          'weight': BodyTwinMetricConsistencyRule(expectedUnit: 'kg'),
        },
      ),
      requiredMetricKeys: const <String>['weight'],
    );

    expect(result.canProceed, isFalse);
    expect(result.trendState.trendsByMetric, isEmpty);
  });
}
