import '../domain/body_twin_observation.dart';
import '../domain/body_twin_snapshot.dart';

/// First stable, offline-only Body Twin foundation boundary.
///
/// It selects the latest eligible local observation for each metric at [asOf].
/// No values are inferred, averaged, persisted, uploaded, or medically
/// interpreted. Equal-time duplicates must be semantically identical; a
/// conflict is rejected rather than silently resolved.
final class BodyTwinFoundation {
  const BodyTwinFoundation();

  BodyTwinSnapshot build({
    required DateTime asOf,
    required Iterable<BodyTwinObservation> observations,
    Iterable<String> requiredMetricKeys = const <String>[],
  }) {
    final normalizedAsOf = asOf.toUtc();
    final latest = <String, BodyTwinObservation>{};

    for (final observation in observations) {
      if (observation.observedAt.isAfter(normalizedAsOf)) {
        continue;
      }

      final current = latest[observation.metricKey];
      if (current == null ||
          observation.observedAt.isAfter(current.observedAt)) {
        latest[observation.metricKey] = observation;
        continue;
      }

      if (observation.observedAt.isAtSameMomentAs(current.observedAt) &&
          !_samePayload(current, observation)) {
        throw StateError(
          'Conflicting Body Twin observations for '
          '${observation.metricKey} at ${observation.observedAt.toIso8601String()}.',
        );
      }
    }

    return BodyTwinSnapshot(
      asOf: normalizedAsOf,
      observationsByMetric: latest,
      requiredMetricKeys: requiredMetricKeys,
    );
  }

  static bool _samePayload(
    BodyTwinObservation left,
    BodyTwinObservation right,
  ) {
    return left.value == right.value &&
        left.unit == right.unit &&
        left.source == right.source &&
        left.reliability == right.reliability;
  }
}
