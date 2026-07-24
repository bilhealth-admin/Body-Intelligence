import 'dart:collection';

/// Explicit lifecycle states for a locally recorded decision outcome.
enum DecisionOutcomeState { pending, succeeded, failed, abandoned }

/// Immutable append-only transition attached to an existing decision record.
final class DecisionOutcomeTransition {
  DecisionOutcomeTransition({
    required this.id,
    required this.decisionRecordId,
    required this.occurredAt,
    required this.fromState,
    required this.toState,
    required this.reason,
    Iterable<String> evidenceIds = const <String>[],
  }) : evidenceIds = UnmodifiableListView<String>(
         evidenceIds.toSet().toList()..sort(),
       ) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (decisionRecordId.trim().isEmpty) {
      throw ArgumentError.value(
        decisionRecordId,
        'decisionRecordId',
        'must not be empty',
      );
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'must not be empty');
    }
    if (fromState == toState) {
      throw ArgumentError('Outcome transition must change state.');
    }
  }

  final String id;
  final String decisionRecordId;
  final DateTime occurredAt;
  final DecisionOutcomeState fromState;
  final DecisionOutcomeState toState;
  final String reason;
  final UnmodifiableListView<String> evidenceIds;
}
