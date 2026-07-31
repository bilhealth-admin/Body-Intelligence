import 'package:body_intelligence_log/features/ai_platform/domain/body_twin_observation.dart';
import 'package:body_intelligence_log/features/ai_platform/services/body_twin_trend_state_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = BodyTwinTrendStateBuilder();

  test('metric and observation ordering is stable across insertion order', () {
    BodyTwinObservation observation(String metric, double value, int day) {
      return BodyTwinObservation(
        metricKey: metric,
        value: value,
        unit: metric == 'weight' ? 'kg' : 'cm',
        observedAt: DateTime.utc(2026, 7, day),
        source: 'manual',
      );
    }

    final first = builder.build(
      asOf: DateTime.utc(2026, 7, 24),
      observations: <BodyTwinObservation>[
        observation('waist', 104, 22),
        observation('weight', 95.1, 23),
        observation('weight', 96, 20),
      ],
    );
    final second = builder.build(
      asOf: DateTime.utc(2026, 7, 24),
      observations: <BodyTwinObservation>[
        observation('weight', 96, 20),
        observation('weight', 95.1, 23),
        observation('waist', 104, 22),
      ],
    );

    expect(first.trendsByMetric.keys, second.trendsByMetric.keys);
    expect(
      first.trendFor('weight')!.observations.map((value) => value.value),
      second.trendFor('weight')!.observations.map((value) => value.value),
    );
  });

  test('returned trend collections are immutable', () {
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
      ],
    );

    expect(() => state.trendsByMetric.clear(), throwsUnsupportedError);
    expect(
      () => state.trendFor('weight')!.observations.clear(),
      throwsUnsupportedError,
    );
  });
}
