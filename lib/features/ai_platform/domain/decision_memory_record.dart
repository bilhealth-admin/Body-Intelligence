import 'dart:collection';

/// Immutable local record of one AI Platform decision and its evidence.
final class DecisionMemoryRecord {
  DecisionMemoryRecord({
    required this.id,
    required this.createdAt,
    required this.decisionKey,
    required this.selectedAction,
    required this.rationale,
    required this.confidence,
    required Iterable<String> evidenceIds,
    required this.outcomeState,
  }) : evidenceIds = UnmodifiableListView<String>(
         (evidenceIds.toList()..sort()),
       ) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (decisionKey.trim().isEmpty) {
      throw ArgumentError.value(
        decisionKey,
        'decisionKey',
        'must not be empty',
      );
    }
    if (selectedAction.trim().isEmpty) {
      throw ArgumentError.value(
        selectedAction,
        'selectedAction',
        'must not be empty',
      );
    }
    if (rationale.trim().isEmpty) {
      throw ArgumentError.value(rationale, 'rationale', 'must not be empty');
    }
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be finite and between 0 and 1',
      );
    }
  }

  final String id;
  final DateTime createdAt;
  final String decisionKey;
  final String selectedAction;
  final String rationale;
  final double confidence;
  final UnmodifiableListView<String> evidenceIds;
  final String outcomeState;
}
