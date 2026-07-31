final class AiCoachPolicy {
  const AiCoachPolicy({
    this.maximumMessageCharacters = 520,
    this.requireInsightSummary = true,
  }) : assert(maximumMessageCharacters >= 120);

  final int maximumMessageCharacters;
  final bool requireInsightSummary;
}
