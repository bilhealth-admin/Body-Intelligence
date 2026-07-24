import 'dart:collection';

import 'body_twin_observation.dart';

/// Immutable, deterministic local representation of the latest known body
/// state at a caller-supplied point in time.
///
/// Missing metrics remain explicit. The snapshot never estimates, repairs, or
/// medically interprets values.
final class BodyTwinSnapshot {
  BodyTwinSnapshot({
    required DateTime asOf,
    required Map<String, BodyTwinObservation> observationsByMetric,
    required Iterable<String> requiredMetricKeys,
  }) : asOf = asOf.toUtc(),
       observationsByMetric = UnmodifiableMapView<String, BodyTwinObservation>(
         SplayTreeMap<String, BodyTwinObservation>.from(observationsByMetric),
       ),
       requiredMetricKeys = UnmodifiableListView<String>(
         _normalizeRequiredKeys(requiredMetricKeys),
       );

  final DateTime asOf;
  final Map<String, BodyTwinObservation> observationsByMetric;
  final List<String> requiredMetricKeys;

  Iterable<String> get availableMetricKeys => observationsByMetric.keys;

  List<String> get missingRequiredMetricKeys => List<String>.unmodifiable(
    requiredMetricKeys.where(
      (metricKey) => !observationsByMetric.containsKey(metricKey),
    ),
  );

  bool get isComplete => missingRequiredMetricKeys.isEmpty;

  double get completeness {
    if (requiredMetricKeys.isEmpty) {
      return 1;
    }
    final availableRequired = requiredMetricKeys.length -
        missingRequiredMetricKeys.length;
    return availableRequired / requiredMetricKeys.length;
  }

  BodyTwinObservation? observationFor(String metricKey) {
    return observationsByMetric[metricKey.trim()];
  }

  static List<String> _normalizeRequiredKeys(Iterable<String> keys) {
    final normalized = SplayTreeSet<String>();
    for (final key in keys) {
      final value = key.trim();
      if (value.isEmpty) {
        throw ArgumentError.value(key, 'requiredMetricKeys', 'must not be empty');
      }
      normalized.add(value);
    }
    return normalized.toList(growable: false);
  }
}
