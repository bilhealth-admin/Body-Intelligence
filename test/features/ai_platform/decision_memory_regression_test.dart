import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'history ordering remains deterministic and returned lists immutable',
    () {
      final memory = DecisionMemory()
        ..remember(_record(id: 'b', hour: 1))
        ..remember(_record(id: 'a', hour: 1))
        ..remember(_record(id: 'c', hour: 2));

      final histories = memory.all;
      expect(histories.map((value) => value.record.id), <String>[
        'c',
        'a',
        'b',
      ]);
      expect(() => histories.add(histories.first), throwsUnsupportedError);
      expect(() => histories.first.transitions.clear(), throwsUnsupportedError);
    },
  );

  test('public facade preserves duplicate record rejection', () {
    final memory = DecisionMemory();
    final record = _record(id: 'decision-1', hour: 0);
    memory.remember(record);

    expect(() => memory.remember(record), throwsStateError);
  });
}

DecisionMemoryRecord _record({required String id, required int hour}) {
  return DecisionMemoryRecord(
    id: id,
    createdAt: DateTime.utc(2026, 7, 24, hour),
    decisionKey: 'daily_action',
    selectedAction: 'hold',
    rationale: 'Deterministic local history.',
    confidence: 0.8,
    evidenceIds: const <String>['evidence-1'],
    outcomeState: 'pending',
  );
}
