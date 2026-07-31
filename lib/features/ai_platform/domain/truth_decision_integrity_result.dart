import 'dart:collection';

/// Explainable integrity issue found between a validated truth report and the
/// decision exposed from it.
enum TruthDecisionIntegrityIssueCode {
  dispositionMismatch,
  rationaleMismatch,
  evidenceMismatch,
  confidenceMismatch,
  missingEvidenceMismatch,
}

/// Immutable issue emitted by [TruthDecisionValidator].
final class TruthDecisionIntegrityIssue {
  TruthDecisionIntegrityIssue({required this.code, required String message})
    : message = _validatedText(message);

  final TruthDecisionIntegrityIssueCode code;
  final String message;

  static String _validatedText(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'message', 'must not be empty');
    }
    return normalized;
  }
}

/// Immutable validation result for one truth-decision gate outcome.
///
/// Rejected gate outcomes are valid because no decision escaped the integrity
/// boundary. Accepted outcomes are valid only when the decision remains
/// consistent with the accepted truth assessment.
final class TruthDecisionIntegrityResult {
  TruthDecisionIntegrityResult({
    required Iterable<TruthDecisionIntegrityIssue> issues,
  }) : issues = UnmodifiableListView<TruthDecisionIntegrityIssue>(
         List.of(issues),
       );

  final List<TruthDecisionIntegrityIssue> issues;

  bool get isValid => issues.isEmpty;
}
