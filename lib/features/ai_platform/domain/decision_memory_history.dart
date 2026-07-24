import 'dart:collection';

import 'decision_memory_record.dart';
import 'decision_outcome_transition.dart';

/// Immutable public projection of one decision and its append-only outcomes.
final class DecisionMemoryHistory {
  DecisionMemoryHistory({
    required this.record,
    required this.currentState,
    required Iterable<DecisionOutcomeTransition> transitions,
  }) : transitions = UnmodifiableListView<DecisionOutcomeTransition>(
         transitions.toList(growable: false),
       );

  final DecisionMemoryRecord record;
  final DecisionOutcomeState currentState;
  final UnmodifiableListView<DecisionOutcomeTransition> transitions;

  bool get isTerminal => currentState != DecisionOutcomeState.pending;
}
