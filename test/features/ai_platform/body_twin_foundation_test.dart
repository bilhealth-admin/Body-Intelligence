import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const foundation = BodyTwinFoundation();
  final asOf = DateTime.utc(2026, 7, 24, 1);

  test('builds a deterministic latest-known snapshot without inference', () {
    final snapshot = foundation.build(
      asOf: asOf,
      observations: <BodyTwinObservation>[
        BodyTwinObservation(
          metricKey: 'weight_kg',
          value: 96.2,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 22),
          source: 'weight_repository',
        ),
        BodyTwinObservation(
          metricKey: 'weight_kg',
          value: 95.1,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 23),
          source: 'weight_repository',
        ),
        BodyTwinObservation(
          metricKey: 'waist_cm',
          value: 104,
          unit: 'cm',
          observedAt: DateTime.utc(2026, 7, 20),
          source: 'profile_measurements',
          reliability: 0.9,
        ),
      ],
      requiredMetricKeys: const <String>['waist_cm', 'weight_kg'],
    );

    expect(snapshot.asOf, asOf);
    expect(snapshot.availableMetricKeys, <String>['waist_cm', 'weight_kg']);
    expect(snapshot.observationFor('weight_kg')?.value, 95.1);
    expect(snapshot.observationFor('waist_cm')?.reliability, 0.9);
    expect(snapshot.isComplete, isTrue);
    expect(snapshot.completeness, 1);
    expect(snapshot.missingRequiredMetricKeys, isEmpty);
  });

  test('excludes future observations and exposes missing required metrics', () {
    final snapshot = foundation.build(
      asOf: asOf,
      observations: <BodyTwinObservation>[
        BodyTwinObservation(
          metricKey: 'weight_kg',
          value: 94.8,
          unit: 'kg',
          observedAt: asOf.add(const Duration(minutes: 1)),
          source: 'weight_repository',
        ),
      ],
      requiredMetricKeys: const <String>['weight_kg', 'waist_cm'],
    );

    expect(snapshot.observationsByMetric, isEmpty);
    expect(snapshot.missingRequiredMetricKeys, <String>[
      'waist_cm',
      'weight_kg',
    ]);
    expect(snapshot.isComplete, isFalse);
    expect(snapshot.completeness, 0);
  });

  test('rejects conflicting equal-time observations', () {
    final observedAt = DateTime.utc(2026, 7, 23);

    expect(
      () => foundation.build(
        asOf: asOf,
        observations: <BodyTwinObservation>[
          BodyTwinObservation(
            metricKey: 'weight_kg',
            value: 95.1,
            unit: 'kg',
            observedAt: observedAt,
            source: 'weight_repository',
          ),
          BodyTwinObservation(
            metricKey: 'weight_kg',
            value: 95.4,
            unit: 'kg',
            observedAt: observedAt,
            source: 'weight_repository',
          ),
        ],
      ),
      throwsStateError,
    );
  });

  test('validates observation values and reliability', () {
    expect(
      () => BodyTwinObservation(
        metricKey: 'weight_kg',
        value: double.nan,
        unit: 'kg',
        observedAt: asOf,
        source: 'weight_repository',
      ),
      throwsArgumentError,
    );
    expect(
      () => BodyTwinObservation(
        metricKey: 'weight_kg',
        value: 95.1,
        unit: 'kg',
        observedAt: asOf,
        source: 'weight_repository',
        reliability: 1.1,
      ),
      throwsArgumentError,
    );
  });
}
