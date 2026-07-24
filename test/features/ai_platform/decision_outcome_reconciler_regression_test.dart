import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_outcome_transition.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_outcome_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'rejects duplicate ids, mismatched records, and non-append-only time',
    () {
      final record = _record('decision-1');
      final reconciler = DecisionOutcomeReconciler();
      final first = _transition(
        id: 'outcome-1',
        decisionId: record.id,
        occurredAt: DateTime.utc(2026, 7, 24, 2),
      );

      reconciler.append(record: record, transition: first);

      expect(
        () => reconciler.append(record: record, transition: first),
        throwsStateError,
      );
      expect(
        () => DecisionOutcomeReconciler().append(
          record: record,
          transition: _transition(
            id: 'outcome-2',
            decisionId: 'another-decision',
            occurredAt: DateTime.utc(2026, 7, 24, 2),
          ),
        ),
        throwsStateError,
      );
      expect(
        () => DecisionOutcomeReconciler().append(
          record: record,
          transition: _transition(
            id: 'outcome-3',
            decisionId: record.id,
            occurredAt: DateTime.utc(2026, 7, 23),
          ),
        ),
        throwsStateError,
      );
    },
  );

  test('history and evidence collections are immutable and deterministic', () {
    final record = _record('decision-1');
    final reconciler = DecisionOutcomeReconciler();
    final transition = DecisionOutcomeTransition(
      id: 'outcome-1',
      decisionRecordId: record.id,
      occurredAt: DateTime.utc(2026, 7, 24, 2),
      fromState: DecisionOutcomeState.pending,
      toState: DecisionOutcomeState.abandoned,
      reason: 'User explicitly declined the action.',
      evidenceIds: const <String>['z', 'a', 'a'],
    );

    reconciler.append(record: record, transition: transition);

    expect(transition.evidenceIds, <String>['a', 'z']);
    expect(
      () => reconciler.historyFor(record.id).add(transition),
      throwsUnsupportedError,
    );
  });
}

DecisionMemoryRecord _record(String id) {
  return DecisionMemoryRecord(
    id: id,
    createdAt: DateTime.utc(2026, 7, 24),
    decisionKey: 'daily_action',
    selectedAction: 'hold',
    rationale: 'Deterministic local decision.',
    confidence: 0.7,
    evidenceIds: const <String>[],
    outcomeState: 'pending',
  );
}

DecisionOutcomeTransition _transition({
  required String id,
  required String decisionId,
  required DateTime occurredAt,
}) {
  return DecisionOutcomeTransition(
    id: id,
    decisionRecordId: decisionId,
    occurredAt: occurredAt,
    fromState: DecisionOutcomeState.pending,
    toState: DecisionOutcomeState.succeeded,
    reason: 'Observed local outcome.',
  );
}
