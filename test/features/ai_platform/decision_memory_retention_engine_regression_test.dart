import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_archive.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_compaction.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_retention.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory_compaction_validator.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory_retention_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compaction cannot silently omit an immutable record', () {
    final memory = DecisionMemory()
      ..remember(_record('a'))
      ..remember(_record('b'));
    final valid = const DecisionMemoryRetentionEngine().compact(
      memory: memory,
      evaluatedAt: DateTime.utc(2026, 7, 24),
      policy: const DecisionMemoryRetentionPolicy(
        terminalGracePeriod: Duration(days: 1),
      ),
    );
    final corrupted = DecisionMemoryCompaction(
      activeArchive: DecisionMemoryArchive(
        schemaVersion: DecisionMemoryArchive.currentSchemaVersion,
        entries: valid.activeArchive.entries.take(1),
      ),
      auditArchive: DecisionMemoryArchive(
        schemaVersion: DecisionMemoryArchive.currentSchemaVersion,
        entries: const <DecisionMemoryArchiveEntry>[],
      ),
      decisions: valid.decisions,
    );

    final integrity = const DecisionMemoryCompactionValidator().validate(
      source: memory,
      compaction: corrupted,
    );

    expect(integrity.isValid, isFalse);
    expect(integrity.issues, contains('missing-record:b'));
  });

  test('rejects negative retention windows and future records', () {
    final memory = DecisionMemory()..remember(_record('future'));
    const engine = DecisionMemoryRetentionEngine();

    expect(
      () => engine.compact(
        memory: memory,
        evaluatedAt: DateTime.utc(2026, 7, 24),
        policy: const DecisionMemoryRetentionPolicy(
          terminalGracePeriod: Duration(days: -1),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.compact(
        memory: memory,
        evaluatedAt: DateTime.utc(2026, 6, 24),
        policy: const DecisionMemoryRetentionPolicy(
          terminalGracePeriod: Duration.zero,
        ),
      ),
      throwsStateError,
    );
  });
}

DecisionMemoryRecord _record(String id) {
  return DecisionMemoryRecord(
    id: id,
    createdAt: DateTime.utc(2026, 7, 1),
    decisionKey: 'test',
    selectedAction: 'observe',
    rationale: 'Regression fixture.',
    confidence: 0.5,
    evidenceIds: const <String>['evidence'],
    outcomeState: 'pending',
  );
}
