final class ScientificValidationPolicy {
  const ScientificValidationPolicy({
    this.minimumConfidence = 0.6,
    this.maximumClaims = 24,
    this.maximumStatementCharacters = 600,
  });

  final double minimumConfidence;
  final int maximumClaims;
  final int maximumStatementCharacters;
}
