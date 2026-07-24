import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_outcome_transition.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory_archive_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips records, transitions, and exact current state', () {
    final memory = DecisionMemory();
    final record = DecisionMemoryRecord(
      id: 'decision-1',
      createdAt: DateTime.utc(2026, 7, 24, 1),
      decisionKey: 'hydration',
      selectedAction: 'drink-water',
      rationale: 'Local evidence supports hydration.',
      confidence: 0.8,
      evidenceIds: const <String>['evidence-b', 'evidence-a'],
      outcomeState: 'pending',
    );
    memory.remember(record);
    memory.appendOutcome(
      DecisionOutcomeTransition(
        id: 'transition-1',
        decisionRecordId: record.id,
        occurredAt: DateTime.utc(2026, 7, 24, 2),
        fromState: DecisionOutcomeState.pending,
        toState: DecisionOutcomeState.succeeded,
        reason: 'Completed locally.',
        evidenceIds: const <String>['outcome-1'],
      ),
    );

    const codec = DecisionMemoryArchiveCodec();
    final restored = codec.decode(codec.encode(memory));
    final history = restored.byId(record.id)!;

    expect(history.record.decisionKey, 'hydration');
    expect(history.record.evidenceIds, <String>['evidence-a', 'evidence-b']);
    expect(history.transitions.single.id, 'transition-1');
    expect(history.currentState, DecisionOutcomeState.succeeded);
  });

  test('exports records in deterministic oldest-first order', () {
    final memory = DecisionMemory();
    memory.remember(_record('later', DateTime.utc(2026, 7, 24, 2)));
    memory.remember(_record('earlier', DateTime.utc(2026, 7, 24, 1)));

    const codec = DecisionMemoryArchiveCodec();
    final entries = codec.encode(memory)['entries']! as List<Object?>;
    final ids = entries.map((entry) {
      final map = entry! as Map<String, Object?>;
      final record = map['record']! as Map<String, Object?>;
      return record['id'];
    });

    expect(ids, <Object?>['earlier', 'later']);
  });
}

DecisionMemoryRecord _record(String id, DateTime createdAt) {
  return DecisionMemoryRecord(
    id: id,
    createdAt: createdAt,
    decisionKey: 'test',
    selectedAction: 'observe',
    rationale: 'Deterministic fixture.',
    confidence: 0.5,
    evidenceIds: const <String>[],
    outcomeState: 'pending',
  );
}
