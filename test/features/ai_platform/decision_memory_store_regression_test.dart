import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'retrieval is stable for equal timestamps and does not expose mutation',
    () {
      final timestamp = DateTime.utc(2026, 7, 24);
      final store = DecisionMemoryStore()
        ..remember(_record('z', timestamp, 'other'))
        ..remember(_record('b', timestamp, 'target'))
        ..remember(_record('a', timestamp, 'target'));

      expect(store.forDecision('target').map((record) => record.id), <String>[
        'a',
        'b',
      ]);
      expect(
        () => store.all.add(_record('x', timestamp, 'target')),
        throwsUnsupportedError,
      );
    },
  );

  test('invalid confidence and empty required values are rejected', () {
    expect(
      () => DecisionMemoryRecord(
        id: '',
        createdAt: DateTime.utc(2026),
        decisionKey: 'key',
        selectedAction: 'hold',
        rationale: 'reason',
        confidence: 1.1,
        evidenceIds: const <String>[],
        outcomeState: 'pending',
      ),
      throwsArgumentError,
    );
  });
}

DecisionMemoryRecord _record(
  String id,
  DateTime createdAt,
  String decisionKey,
) {
  return DecisionMemoryRecord(
    id: id,
    createdAt: createdAt,
    decisionKey: decisionKey,
    selectedAction: 'hold',
    rationale: 'Deterministic test rationale.',
    confidence: 0.5,
    evidenceIds: const <String>[],
    outcomeState: 'pending',
  );
}
