/// Caller-owned candidate that may be selected from a resolved truth assessment.
///
/// The candidate contains no inference policy. It only describes a value that
/// a deterministic bridge may select when the Truth Engine resolves a
/// proposition as supported or contradicted.
final class TruthDecisionCandidate<T> {
  factory TruthDecisionCandidate({
    required T value,
    required String label,
    required String summary,
    required String reasonWhenNotChosen,
  }) {
    return TruthDecisionCandidate._(
      value,
      _validatedText(label, 'label'),
      _validatedText(summary, 'summary'),
      _validatedText(reasonWhenNotChosen, 'reasonWhenNotChosen'),
    );
  }

  const TruthDecisionCandidate._(
    this.value,
    this.label,
    this.summary,
    this.reasonWhenNotChosen,
  );

  final T value;
  final String label;
  final String summary;
  final String reasonWhenNotChosen;

  static String _validatedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }
}
