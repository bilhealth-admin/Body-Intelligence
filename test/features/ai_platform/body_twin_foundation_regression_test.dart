import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('input ordering cannot change the selected Body Twin state', () {
    const foundation = BodyTwinFoundation();
    final asOf = DateTime.utc(2026, 7, 24);
    final observations = <BodyTwinObservation>[
      BodyTwinObservation(
        metricKey: 'weight_kg',
        value: 95.1,
        unit: 'kg',
        observedAt: DateTime.utc(2026, 7, 23),
        source: 'weight_repository',
      ),
      BodyTwinObservation(
        metricKey: 'weight_kg',
        value: 96.2,
        unit: 'kg',
        observedAt: DateTime.utc(2026, 7, 22),
        source: 'weight_repository',
      ),
      BodyTwinObservation(
        metricKey: 'waist_cm',
        value: 104,
        unit: 'cm',
        observedAt: DateTime.utc(2026, 7, 20),
        source: 'profile_measurements',
      ),
    ];

    final forward = foundation.build(
      asOf: asOf,
      observations: observations,
      requiredMetricKeys: const <String>['weight_kg', 'waist_cm'],
    );
    final reverse = foundation.build(
      asOf: asOf,
      observations: observations.reversed,
      requiredMetricKeys: const <String>['waist_cm', 'weight_kg', 'weight_kg'],
    );

    expect(reverse.availableMetricKeys, forward.availableMetricKeys);
    expect(
      reverse.observationFor('weight_kg')?.value,
      forward.observationFor('weight_kg')?.value,
    );
    expect(reverse.requiredMetricKeys, forward.requiredMetricKeys);
    expect(reverse.completeness, forward.completeness);
  });

  test('snapshot collections are immutable', () {
    const foundation = BodyTwinFoundation();
    final snapshot = foundation.build(
      asOf: DateTime.utc(2026, 7, 24),
      observations: <BodyTwinObservation>[
        BodyTwinObservation(
          metricKey: 'weight_kg',
          value: 95.1,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 23),
          source: 'weight_repository',
        ),
      ],
      requiredMetricKeys: const <String>['weight_kg'],
    );

    expect(
      () => snapshot.observationsByMetric.clear(),
      throwsUnsupportedError,
    );
    expect(() => snapshot.requiredMetricKeys.add('waist_cm'), throwsUnsupportedError);
  });
}
