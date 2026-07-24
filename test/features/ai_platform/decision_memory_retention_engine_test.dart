import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_record.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_memory_retention.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/decision_outcome_transition.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory_compaction_validator.dart';
import 'package:body_intelligence_log/features/ai_platform/services/decision_memory_retention_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'moves old terminal records intact while pending records stay active',
    () {
      final memory = DecisionMemory();
      final pending = _record('pending', DateTime.utc(2026, 7, 1));
      final terminal = _record('terminal', DateTime.utc(2026, 7, 1));
      memory
        ..remember(pending)
        ..remember(terminal)
        ..appendOutcome(
          DecisionOutcomeTransition(
            id: 'terminal-outcome',
            decisionRecordId: terminal.id,
            occurredAt: DateTime.utc(2026, 7, 2),
            fromState: DecisionOutcomeState.pending,
            toState: DecisionOutcomeState.succeeded,
            reason: 'Completed.',
            evidenceIds: const <String>['outcome-evidence'],
          ),
        );

      const engine = DecisionMemoryRetentionEngine();
      final result = engine.compact(
        memory: memory,
        evaluatedAt: DateTime.utc(2026, 7, 24),
        policy: const DecisionMemoryRetentionPolicy(
          terminalGracePeriod: Duration(days: 7),
        ),
      );

      expect(
        result.activeArchive.entries.map((entry) => entry.record.id),
        <String>['pending'],
      );
      expect(
        result.auditArchive.entries.map((entry) => entry.record.id),
        <String>['terminal'],
      );
      expect(
        result.auditArchive.entries.single.transitions.single.id,
        'terminal-outcome',
      );
      expect(
        const DecisionMemoryCompactionValidator()
            .validate(source: memory, compaction: result)
            .isValid,
        isTrue,
      );
    },
  );

  test('retention decisions are deterministic and explainable', () {
    final memory = DecisionMemory()
      ..remember(_record('a', DateTime.utc(2026, 7, 1)));
    const engine = DecisionMemoryRetentionEngine();
    const policy = DecisionMemoryRetentionPolicy(
      terminalGracePeriod: Duration(days: 7),
    );

    final first = engine.compact(
      memory: memory,
      evaluatedAt: DateTime.utc(2026, 7, 24),
      policy: policy,
    );
    final second = engine.compact(
      memory: memory,
      evaluatedAt: DateTime.utc(2026, 7, 24),
      policy: policy,
    );

    expect(first.decisions.single.recordId, second.decisions.single.recordId);
    expect(
      first.decisions.single.disposition,
      second.decisions.single.disposition,
    );
    expect(first.decisions.single.reason, isNotEmpty);
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
    evidenceIds: const <String>['record-evidence'],
    outcomeState: 'pending',
  );
}
