import 'body_twin_observation.dart';

/// Immutable provenance projected from one accepted Body Twin observation.
final class BodyTwinMetricProvenance {
  const BodyTwinMetricProvenance({
    required this.metricKey,
    required this.source,
    required this.observedAt,
    required this.reliability,
  });

  factory BodyTwinMetricProvenance.fromObservation(
    BodyTwinObservation observation,
  ) {
    return BodyTwinMetricProvenance(
      metricKey: observation.metricKey,
      source: observation.source,
      observedAt: observation.observedAt,
      reliability: observation.reliability,
    );
  }

  final String metricKey;
  final String source;
  final DateTime observedAt;
  final double reliability;
}
