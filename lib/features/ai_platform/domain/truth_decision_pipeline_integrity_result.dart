import 'dart:collection';

/// Stable issue codes emitted when the trusted Truth/Explain pipeline result
/// no longer preserves its established provenance and exposure invariants.
enum TruthDecisionPipelineIntegrityIssueCode {
  reportReferenceMismatch,
  exposableDecisionMissing,
  unsafeRejectedValidationExposure,
}

/// One explainable inconsistency found in a trusted pipeline result.
final class TruthDecisionPipelineIntegrityIssue {
  TruthDecisionPipelineIntegrityIssue({
    required this.code,
    required String message,
  }) : message = _validatedText(message);

  final TruthDecisionPipelineIntegrityIssueCode code;
  final String message;

  static String _validatedText(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'message', 'must not be empty');
    }
    return normalized;
  }
}

/// Immutable integrity result for one trusted Truth/Explain pipeline output.
final class TruthDecisionPipelineIntegrityResult {
  TruthDecisionPipelineIntegrityResult({
    required Iterable<TruthDecisionPipelineIntegrityIssue> issues,
  }) : issues = UnmodifiableListView<TruthDecisionPipelineIntegrityIssue>(
         List<TruthDecisionPipelineIntegrityIssue>.of(issues),
       );

  final List<TruthDecisionPipelineIntegrityIssue> issues;

  bool get isValid => issues.isEmpty;
}
