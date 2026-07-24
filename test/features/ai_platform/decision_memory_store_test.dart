import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores and retrieves immutable decision records deterministically', () {
    final store = DecisionMemoryStore();
    final older = _record('a', DateTime.utc(2026, 7, 20), <String>['z', 'a']);
    final newer = _record('b', DateTime.utc(2026, 7, 21), <String>['c']);

    store.remember(older);
    store.remember(newer);

    expect(store.byId('a'), same(older));
    expect(store.all.map((record) => record.id), <String>['b', 'a']);
    expect(older.evidenceIds, <String>['a', 'z']);
  });

  test('rejects duplicate record ids', () {
    final store = DecisionMemoryStore()
      ..remember(_record('a', DateTime.utc(2026)));

    expect(
      () => store.remember(_record('a', DateTime.utc(2026, 2))),
      throwsStateError,
    );
  });
}

DecisionMemoryRecord _record(
  String id,
  DateTime createdAt, [
  List<String> evidenceIds = const <String>[],
]) {
  return DecisionMemoryRecord(
    id: id,
    createdAt: createdAt,
    decisionKey: 'daily_action',
    selectedAction: 'hold',
    rationale: 'Trusted evidence is insufficient for escalation.',
    confidence: 0.8,
    evidenceIds: evidenceIds,
    outcomeState: 'pending',
  );
}
