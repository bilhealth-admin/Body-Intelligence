import 'dart:collection';

import 'body_twin_observation.dart';

/// Immutable, deterministic history for one Body Twin metric.
///
/// This state preserves observed values only. It does not interpolate,
/// forecast, repair, convert, or medically interpret measurements.
final class BodyTwinMetricTrend {
  BodyTwinMetricTrend({
    required String metricKey,
    required Iterable<BodyTwinObservation> observations,
  }) : metricKey = _normalizeMetricKey(metricKey),
       observations = UnmodifiableListView<BodyTwinObservation>(
         _sortedObservations(observations),
       );

  final String metricKey;
  final List<BodyTwinObservation> observations;

  BodyTwinObservation get latest => observations.last;

  static String _normalizeMetricKey(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'metricKey', 'must not be empty');
    }
    return normalized;
  }

  static List<BodyTwinObservation> _sortedObservations(
    Iterable<BodyTwinObservation> values,
  ) {
    final sorted = values.toList(growable: false)
      ..sort((left, right) {
        final time = left.observedAt.compareTo(right.observedAt);
        if (time != 0) {
          return time;
        }
        final source = left.source.compareTo(right.source);
        if (source != 0) {
          return source;
        }
        return left.value.compareTo(right.value);
      });
    if (sorted.isEmpty) {
      throw ArgumentError.value(values, 'observations', 'must not be empty');
    }
    return sorted;
  }
}

/// Trend-ready Body Twin state built exclusively from caller-provided facts.
final class BodyTwinTrendState {
  BodyTwinTrendState({
    required DateTime asOf,
    required Map<String, BodyTwinMetricTrend> trendsByMetric,
  }) : asOf = asOf.toUtc(),
       trendsByMetric = UnmodifiableMapView<String, BodyTwinMetricTrend>(
         SplayTreeMap<String, BodyTwinMetricTrend>.from(trendsByMetric),
       );

  final DateTime asOf;
  final Map<String, BodyTwinMetricTrend> trendsByMetric;

  BodyTwinMetricTrend? trendFor(String metricKey) {
    return trendsByMetric[metricKey.trim()];
  }
}
