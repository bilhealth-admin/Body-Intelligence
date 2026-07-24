import 'dart:collection';

/// Retention outcomes are movement decisions, never deletion instructions.
enum DecisionMemoryRetentionDisposition { active, auditArchive }

/// Caller-owned deterministic retention policy for local Decision Memory.
final class DecisionMemoryRetentionPolicy {
  const DecisionMemoryRetentionPolicy({required this.terminalGracePeriod});

  final Duration terminalGracePeriod;

  void validate() {
    if (terminalGracePeriod.isNegative) {
      throw ArgumentError.value(
        terminalGracePeriod,
        'terminalGracePeriod',
        'must not be negative',
      );
    }
  }
}

/// Explainable retention decision for one immutable decision record.
final class DecisionMemoryRetentionDecision {
  DecisionMemoryRetentionDecision({
    required this.recordId,
    required this.disposition,
    required this.evaluatedAt,
    required this.referenceTime,
    required this.reason,
    required Iterable<String> evidenceIds,
  }) : evidenceIds = UnmodifiableListView<String>(
         evidenceIds.toSet().toList()..sort(),
       ) {
    if (recordId.trim().isEmpty) {
      throw ArgumentError.value(recordId, 'recordId', 'must not be empty');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'must not be empty');
    }
  }

  final String recordId;
  final DecisionMemoryRetentionDisposition disposition;
  final DateTime evaluatedAt;
  final DateTime referenceTime;
  final String reason;
  final UnmodifiableListView<String> evidenceIds;
}
