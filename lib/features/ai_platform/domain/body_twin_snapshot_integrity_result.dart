import 'dart:collection';

/// Stable issue codes emitted by deterministic Body Twin snapshot validation.
enum BodyTwinSnapshotIntegrityIssueCode {
  futureObservation,
  metricKeyMismatch,
  provenanceMetricKeyMismatch,
  provenanceObservedAtMismatch,
  provenanceReliabilityMismatch,
  provenanceSourceMismatch,
}

/// One explainable inconsistency found in a Body Twin snapshot envelope.
final class BodyTwinSnapshotIntegrityIssue {
  BodyTwinSnapshotIntegrityIssue({
    required this.code,
    required String metricKey,
    required String message,
  }) : metricKey = _validatedText(metricKey, 'metricKey'),
       message = _validatedText(message, 'message');

  final BodyTwinSnapshotIntegrityIssueCode code;
  final String metricKey;
  final String message;

  static String _validatedText(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }
}

/// Immutable deterministic snapshot validation result.
final class BodyTwinSnapshotIntegrityResult {
  BodyTwinSnapshotIntegrityResult({
    required Iterable<BodyTwinSnapshotIntegrityIssue> issues,
  }) : issues = UnmodifiableListView<BodyTwinSnapshotIntegrityIssue>(
         List<BodyTwinSnapshotIntegrityIssue>.of(issues),
       );

  final List<BodyTwinSnapshotIntegrityIssue> issues;

  bool get isValid => issues.isEmpty;
}
