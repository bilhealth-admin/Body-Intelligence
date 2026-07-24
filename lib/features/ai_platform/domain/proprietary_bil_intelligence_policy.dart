final class ProprietaryBilIntelligencePolicy {
  const ProprietaryBilIntelligencePolicy({
    this.minimumSignalConfidence = 0.7,
    this.maximumSignals = 12,
    this.maximumSummaryCharacters = 1200,
  });

  final double minimumSignalConfidence;
  final int maximumSignals;
  final int maximumSummaryCharacters;
}
