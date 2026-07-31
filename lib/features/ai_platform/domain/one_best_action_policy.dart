final class OneBestActionPolicy {
  const OneBestActionPolicy({
    required this.minimumConfidence,
    required this.minimumScore,
    required this.maximumCandidates,
  });

  final double minimumConfidence;
  final double minimumScore;
  final int maximumCandidates;

  void validate() {
    if (minimumConfidence < 0 || minimumConfidence > 1) {
      throw ArgumentError.value(
        minimumConfidence,
        'minimumConfidence',
        'must be in [0, 1]',
      );
    }
    if (maximumCandidates < 1) {
      throw ArgumentError.value(
        maximumCandidates,
        'maximumCandidates',
        'must be positive',
      );
    }
  }
}
