import '../domain/decision_memory_record.dart';

/// Deterministic in-memory repository boundary for local decision history.
///
/// Persistence adapters can be introduced later without changing the domain
/// contract. This implementation has no network, provider, or cloud dependency.
final class DecisionMemoryStore {
  final Map<String, DecisionMemoryRecord> _records =
      <String, DecisionMemoryRecord>{};

  void remember(DecisionMemoryRecord record) {
    final existing = _records[record.id];
    if (existing != null) {
      throw StateError('Decision memory id already exists: ${record.id}');
    }
    _records[record.id] = record;
  }

  DecisionMemoryRecord? byId(String id) => _records[id];

  List<DecisionMemoryRecord> forDecision(String decisionKey) {
    final matches =
        _records.values
            .where((record) => record.decisionKey == decisionKey)
            .toList()
          ..sort(_compareNewestFirst);
    return List<DecisionMemoryRecord>.unmodifiable(matches);
  }

  List<DecisionMemoryRecord> get all {
    final records = _records.values.toList()..sort(_compareNewestFirst);
    return List<DecisionMemoryRecord>.unmodifiable(records);
  }

  static int _compareNewestFirst(
    DecisionMemoryRecord left,
    DecisionMemoryRecord right,
  ) {
    final time = right.createdAt.compareTo(left.createdAt);
    if (time != 0) {
      return time;
    }
    return left.id.compareTo(right.id);
  }
}
