import 'dart:collection';

/// Stable issue codes emitted by deterministic truth-report validation.
enum TruthIntegrityIssueCode {
  assessmentDirectionMismatch,
  conflictMarginMismatch,
  conflictSignalNotMatched,
  conflictStatusMismatch,
  evidenceCountMismatch,
  matchedRuleMissingFromConflict,
}

/// One explainable inconsistency found in a truth evaluation report.
final class TruthIntegrityIssue {
  TruthIntegrityIssue({
    required this.code,
    required String message,
    required String subjectKey,
  }) : message = _validatedText(message, 'message'),
       subjectKey = _validatedText(subjectKey, 'subjectKey');

  final TruthIntegrityIssueCode code;
  final String message;
  final String subjectKey;

  static String _validatedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }
}

/// Immutable result of deterministic truth-report integrity validation.
final class TruthIntegrityResult {
  TruthIntegrityResult({required Iterable<TruthIntegrityIssue> issues})
    : issues = UnmodifiableListView<TruthIntegrityIssue>(
        List<TruthIntegrityIssue>.of(issues),
      );

  final List<TruthIntegrityIssue> issues;

  bool get isValid => issues.isEmpty;
}
