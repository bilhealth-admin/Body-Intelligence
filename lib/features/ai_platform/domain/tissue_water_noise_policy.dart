final class TissueWaterNoisePolicy {
  const TissueWaterNoisePolicy({
    this.weightMetricKey = 'weight',
    this.minimumObservations = 2,
    this.dominanceToleranceKg = 0.25,
    this.maximumSupportedGap = const Duration(days: 14),
  });

  final String weightMetricKey;
  final int minimumObservations;
  final double dominanceToleranceKg;
  final Duration maximumSupportedGap;

  void validate() {
    if (weightMetricKey.trim().isEmpty) {
      throw ArgumentError.value(
        weightMetricKey,
        'weightMetricKey',
        'must not be empty',
      );
    }
    if (minimumObservations < 2) {
      throw ArgumentError.value(
        minimumObservations,
        'minimumObservations',
        'must be at least 2',
      );
    }
    if (dominanceToleranceKg < 0) {
      throw ArgumentError.value(
        dominanceToleranceKg,
        'dominanceToleranceKg',
        'must not be negative',
      );
    }
    if (maximumSupportedGap <= Duration.zero) {
      throw ArgumentError.value(
        maximumSupportedGap,
        'maximumSupportedGap',
        'must be positive',
      );
    }
  }
}
