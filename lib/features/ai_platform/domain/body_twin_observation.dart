/// One locally produced, time-bound measurement that may contribute to a
/// Body Twin snapshot.
///
/// The observation is deliberately generic so feature-owned deterministic
/// engines can publish measurements without coupling the AI Platform to their
/// persistence models. It performs no inference and contains no provider data.
final class BodyTwinObservation {
  BodyTwinObservation({
    required String metricKey,
    required this.value,
    required String unit,
    required DateTime observedAt,
    required String source,
    this.reliability = 1,
  }) : metricKey = _normalizedText(metricKey, 'metricKey'),
       unit = _normalizedText(unit, 'unit'),
       observedAt = observedAt.toUtc(),
       source = _normalizedText(source, 'source') {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    if (!reliability.isFinite || reliability < 0 || reliability > 1) {
      throw ArgumentError.value(
        reliability,
        'reliability',
        'must be finite and between 0 and 1',
      );
    }
  }

  final String metricKey;
  final double value;
  final String unit;
  final DateTime observedAt;
  final String source;
  final double reliability;

  static String _normalizedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }
}
