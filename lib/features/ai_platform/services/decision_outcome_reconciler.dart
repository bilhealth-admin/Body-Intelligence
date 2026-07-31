import '../domain/decision_memory_record.dart';
import '../domain/decision_outcome_transition.dart';

/// Local append-only outcome reconciliation for immutable decision records.
final class DecisionOutcomeReconciler {
  final Map<String, DecisionOutcomeTransition> _transitionsById =
      <String, DecisionOutcomeTransition>{};
  final Map<String, List<DecisionOutcomeTransition>> _historyByDecision =
      <String, List<DecisionOutcomeTransition>>{};

  DecisionOutcomeState currentState(DecisionMemoryRecord record) {
    final history = _historyByDecision[record.id];
    if (history == null || history.isEmpty) {
      return _parseInitialState(record.outcomeState);
    }
    return history.last.toState;
  }

  void append({
    required DecisionMemoryRecord record,
    required DecisionOutcomeTransition transition,
  }) {
    if (transition.decisionRecordId != record.id) {
      throw StateError(
        'Outcome transition targets a different decision record.',
      );
    }
    if (_transitionsById.containsKey(transition.id)) {
      throw StateError(
        'Outcome transition id already exists: ${transition.id}',
      );
    }

    final current = currentState(record);
    if (transition.fromState != current) {
      throw StateError(
        'Outcome transition starts at ${transition.fromState.name}, '
        'but current state is ${current.name}.',
      );
    }
    if (!_isAllowed(current, transition.toState)) {
      throw StateError(
        'Illegal outcome transition: ${current.name} -> '
        '${transition.toState.name}.',
      );
    }

    final history = _historyByDecision.putIfAbsent(
      record.id,
      () => <DecisionOutcomeTransition>[],
    );
    if (history.isNotEmpty &&
        transition.occurredAt.isBefore(history.last.occurredAt)) {
      throw StateError('Outcome transition time must be append-only.');
    }
    if (history.isEmpty && transition.occurredAt.isBefore(record.createdAt)) {
      throw StateError(
        'Outcome transition cannot predate the decision record.',
      );
    }

    history.add(transition);
    _transitionsById[transition.id] = transition;
  }

  List<DecisionOutcomeTransition> historyFor(String decisionRecordId) {
    return List<DecisionOutcomeTransition>.unmodifiable(
      _historyByDecision[decisionRecordId] ??
          const <DecisionOutcomeTransition>[],
    );
  }

  static DecisionOutcomeState _parseInitialState(String value) {
    final normalized = value.trim().toLowerCase();
    for (final state in DecisionOutcomeState.values) {
      if (state.name == normalized) {
        return state;
      }
    }
    throw StateError('Unsupported decision outcome state: $value');
  }

  static bool _isAllowed(DecisionOutcomeState from, DecisionOutcomeState to) {
    return from == DecisionOutcomeState.pending &&
        (to == DecisionOutcomeState.succeeded ||
            to == DecisionOutcomeState.failed ||
            to == DecisionOutcomeState.abandoned);
  }
}
