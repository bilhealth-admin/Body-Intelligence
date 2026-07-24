import '../domain/decision_memory_history.dart';
import '../domain/decision_memory_record.dart';
import '../domain/decision_outcome_transition.dart';
import 'decision_memory_store.dart';
import 'decision_outcome_reconciler.dart';

/// Stable local facade over immutable decision records and outcome history.
///
/// The facade owns no recommendation, forecasting, provider, or persistence
/// policy. It delegates storage and transition validation to the established
/// Decision Memory components.
final class DecisionMemory {
  DecisionMemory({
    DecisionMemoryStore? store,
    DecisionOutcomeReconciler? reconciler,
  }) : _store = store ?? DecisionMemoryStore(),
       _reconciler = reconciler ?? DecisionOutcomeReconciler();

  final DecisionMemoryStore _store;
  final DecisionOutcomeReconciler _reconciler;

  void remember(DecisionMemoryRecord record) => _store.remember(record);

  void appendOutcome(DecisionOutcomeTransition transition) {
    final record = _store.byId(transition.decisionRecordId);
    if (record == null) {
      throw StateError(
        'Decision memory record does not exist: '
        '${transition.decisionRecordId}',
      );
    }
    _reconciler.append(record: record, transition: transition);
  }

  DecisionMemoryHistory? byId(String id) {
    final record = _store.byId(id);
    return record == null ? null : _project(record);
  }

  List<DecisionMemoryHistory> forDecision(String decisionKey) {
    return List<DecisionMemoryHistory>.unmodifiable(
      _store.forDecision(decisionKey).map(_project),
    );
  }

  List<DecisionMemoryHistory> get all {
    return List<DecisionMemoryHistory>.unmodifiable(_store.all.map(_project));
  }

  DecisionMemoryHistory _project(DecisionMemoryRecord record) {
    return DecisionMemoryHistory(
      record: record,
      currentState: _reconciler.currentState(record),
      transitions: _reconciler.historyFor(record.id),
    );
  }
}
