final class PromptEnginePolicy {
  const PromptEnginePolicy({
    this.maximumContextLines = 12,
    this.maximumContextCharacters = 2400,
    this.maximumOutputCharacters = 1200,
  });

  final int maximumContextLines;
  final int maximumContextCharacters;
  final int maximumOutputCharacters;
}
