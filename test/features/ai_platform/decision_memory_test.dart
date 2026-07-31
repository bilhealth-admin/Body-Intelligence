import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_outcome_transition.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'projects a decision with deterministic append-only outcome history',
    () {
      final memory = DecisionMemory();
      final record = _record(id: 'decision-1');
      final transition = DecisionOutcomeTransition(
        id: 'transition-1',
        decisionRecordId: record.id,
        occurredAt: DateTime.utc(2026, 7, 24, 1),
        fromState: DecisionOutcomeState.pending,
        toState: DecisionOutcomeState.succeeded,
        reason: 'Observed local outcome.',
        evidenceIds: const <String>['evidence-2'],
      );

      memory.remember(record);
      memory.appendOutcome(transition);

      final history = memory.byId(record.id)!;
      expect(history.record, same(record));
      expect(history.currentState, DecisionOutcomeState.succeeded);
      expect(history.transitions, <DecisionOutcomeTransition>[transition]);
      expect(history.isTerminal, isTrue);
    },
  );

  test('rejects an outcome for an unknown decision record', () {
    final memory = DecisionMemory();

    expect(
      () => memory.appendOutcome(
        DecisionOutcomeTransition(
          id: 'transition-1',
          decisionRecordId: 'missing',
          occurredAt: DateTime.utc(2026, 7, 24),
          fromState: DecisionOutcomeState.pending,
          toState: DecisionOutcomeState.failed,
          reason: 'No matching record.',
        ),
      ),
      throwsStateError,
    );
  });
}

DecisionMemoryRecord _record({required String id}) {
  return DecisionMemoryRecord(
    id: id,
    createdAt: DateTime.utc(2026, 7, 24),
    decisionKey: 'daily_action',
    selectedAction: 'hold',
    rationale: 'Trusted evidence is insufficient for escalation.',
    confidence: 0.8,
    evidenceIds: const <String>['evidence-1'],
    outcomeState: 'pending',
  );
}
