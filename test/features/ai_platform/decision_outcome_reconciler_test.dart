import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_outcome_transition.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_outcome_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'appends a valid pending outcome transition without mutating decision',
    () {
      final record = _record();
      final reconciler = DecisionOutcomeReconciler();
      final transition = _transition(
        id: 'outcome-1',
        from: DecisionOutcomeState.pending,
        to: DecisionOutcomeState.succeeded,
      );

      reconciler.append(record: record, transition: transition);

      expect(reconciler.currentState(record), DecisionOutcomeState.succeeded);
      expect(reconciler.historyFor(record.id), <DecisionOutcomeTransition>[
        transition,
      ]);
      expect(record.outcomeState, 'pending');
    },
  );

  test('rejects terminal-state rewrites', () {
    final record = _record();
    final reconciler = DecisionOutcomeReconciler()
      ..append(
        record: record,
        transition: _transition(
          id: 'outcome-1',
          from: DecisionOutcomeState.pending,
          to: DecisionOutcomeState.failed,
        ),
      );

    expect(
      () => reconciler.append(
        record: record,
        transition: _transition(
          id: 'outcome-2',
          from: DecisionOutcomeState.failed,
          to: DecisionOutcomeState.succeeded,
          occurredAt: DateTime.utc(2026, 7, 25),
        ),
      ),
      throwsStateError,
    );
  });
}

DecisionMemoryRecord _record() {
  return DecisionMemoryRecord(
    id: 'decision-1',
    createdAt: DateTime.utc(2026, 7, 24),
    decisionKey: 'daily_action',
    selectedAction: 'hold',
    rationale: 'Trusted evidence is insufficient for escalation.',
    confidence: 0.8,
    evidenceIds: const <String>['evidence-1'],
    outcomeState: 'pending',
  );
}

DecisionOutcomeTransition _transition({
  required String id,
  required DecisionOutcomeState from,
  required DecisionOutcomeState to,
  DateTime? occurredAt,
}) {
  return DecisionOutcomeTransition(
    id: id,
    decisionRecordId: 'decision-1',
    occurredAt: occurredAt ?? DateTime.utc(2026, 7, 24, 1),
    fromState: from,
    toState: to,
    reason: 'Observed local outcome.',
    evidenceIds: const <String>['evidence-2'],
  );
}
