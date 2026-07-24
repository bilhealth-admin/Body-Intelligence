import '../domain/body_twin_observation.dart';
import '../domain/body_twin_trend_state.dart';

/// Builds deterministic trend-ready state without deriving new measurements.
final class BodyTwinTrendStateBuilder {
  const BodyTwinTrendStateBuilder();

  BodyTwinTrendState build({
    required DateTime asOf,
    required Iterable<BodyTwinObservation> observations,
  }) {
    final normalizedAsOf = asOf.toUtc();
    final grouped = <String, List<BodyTwinObservation>>{};

    for (final observation in observations) {
      if (observation.observedAt.isAfter(normalizedAsOf)) {
        continue;
      }
      grouped
          .putIfAbsent(observation.metricKey, () => <BodyTwinObservation>[])
          .add(observation);
    }

    return BodyTwinTrendState(
      asOf: normalizedAsOf,
      trendsByMetric: <String, BodyTwinMetricTrend>{
        for (final entry in grouped.entries)
          entry.key: BodyTwinMetricTrend(
            metricKey: entry.key,
            observations: entry.value,
          ),
      },
    );
  }
}
