class PerformanceSamples {
  const PerformanceSamples._();

  static Duration median(Iterable<Duration> samples) {
    final ordered = List<Duration>.of(samples)..sort();
    if (ordered.isEmpty || ordered.length.isEven) {
      throw ArgumentError.value(
        ordered.length,
        'samples',
        'must contain a non-empty odd number of durations',
      );
    }
    return ordered[ordered.length ~/ 2];
  }
}
