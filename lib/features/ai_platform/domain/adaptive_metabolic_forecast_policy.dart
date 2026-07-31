final class AdaptiveMetabolicForecastPolicy {
  const AdaptiveMetabolicForecastPolicy({
    required this.horizons,
    this.kcalPerKgTissue = 7700,
    this.minimumConfidence = 0.5,
    this.maximumHorizon = const Duration(days: 90),
  });

  final List<Duration> horizons;
  final double kcalPerKgTissue;
  final double minimumConfidence;
  final Duration maximumHorizon;

  void validate() {
    if (horizons.isEmpty || horizons.any((value) => value <= Duration.zero)) {
      throw ArgumentError.value(
        horizons,
        'horizons',
        'must be positive and non-empty',
      );
    }
    if (horizons.toSet().length != horizons.length) {
      throw ArgumentError.value(horizons, 'horizons', 'must be unique');
    }
    if (horizons.any((value) => value > maximumHorizon)) {
      throw ArgumentError.value(horizons, 'horizons', 'exceeds maximumHorizon');
    }
    if (kcalPerKgTissue <= 0) {
      throw ArgumentError.value(
        kcalPerKgTissue,
        'kcalPerKgTissue',
        'must be positive',
      );
    }
    if (minimumConfidence < 0 || minimumConfidence > 1) {
      throw ArgumentError.value(
        minimumConfidence,
        'minimumConfidence',
        'must be in [0, 1]',
      );
    }
  }
}
