class AutomatedHealthInsightPolicy {
  const AutomatedHealthInsightPolicy({
    this.maximumEvidenceItems = 3,
    this.maximumBodyCharacters = 420,
    this.minimumConfidence = 0.6,
  }) : assert(maximumEvidenceItems > 0),
       assert(maximumBodyCharacters >= 80),
       assert(minimumConfidence >= 0 && minimumConfidence <= 1);

  final int maximumEvidenceItems;
  final int maximumBodyCharacters;
  final double minimumConfidence;
}
