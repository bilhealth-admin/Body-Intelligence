import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_trend_state_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = BodyTwinTrendStateBuilder();

  test('builds ordered trend history from observed facts only', () {
    final state = builder.build(
      asOf: DateTime.utc(2026, 7, 24),
      observations: <BodyTwinObservation>[
        BodyTwinObservation(
          metricKey: 'weight',
          value: 95.1,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 23),
          source: 'manual',
        ),
        BodyTwinObservation(
          metricKey: 'weight',
          value: 96.0,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 20),
          source: 'manual',
        ),
      ],
    );

    final trend = state.trendFor('weight');
    expect(trend, isNotNull);
    expect(trend!.observations.map((value) => value.value), <double>[
      96.0,
      95.1,
    ]);
    expect(trend.latest.value, 95.1);
  });

  test('excludes observations after the explicit as-of instant', () {
    final state = builder.build(
      asOf: DateTime.utc(2026, 7, 24),
      observations: <BodyTwinObservation>[
        BodyTwinObservation(
          metricKey: 'weight',
          value: 95.1,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 23),
          source: 'manual',
        ),
        BodyTwinObservation(
          metricKey: 'weight',
          value: 94.0,
          unit: 'kg',
          observedAt: DateTime.utc(2026, 7, 25),
          source: 'manual',
        ),
      ],
    );

    expect(state.trendFor('weight')!.observations.single.value, 95.1);
  });
}
