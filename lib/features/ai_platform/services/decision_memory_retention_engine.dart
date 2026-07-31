import '../domain/decision_memory_archive.dart';
import '../domain/decision_memory_compaction.dart';
import '../domain/decision_memory_history.dart';
import '../domain/decision_memory_retention.dart';
import '../domain/decision_outcome_transition.dart';
import 'decision_memory.dart';
import 'decision_memory_archive_codec.dart';

/// Deterministic retention and lossless compaction for local Decision Memory.
///
/// Compaction moves terminal records between complete archives. It never
/// deletes records, transitions, rationale, confidence, or evidence.
final class DecisionMemoryRetentionEngine {
  const DecisionMemoryRetentionEngine({
    this.codec = const DecisionMemoryArchiveCodec(),
  });

  final DecisionMemoryArchiveCodec codec;

  DecisionMemoryRetentionDecision evaluate({
    required DecisionMemoryHistory history,
    required DateTime evaluatedAt,
    required DecisionMemoryRetentionPolicy policy,
  }) {
    policy.validate();
    final now = evaluatedAt.toUtc();
    final createdAt = history.record.createdAt.toUtc();
    if (createdAt.isAfter(now)) {
      throw StateError('Decision record cannot be evaluated before creation.');
    }

    final referenceTime = history.transitions.isEmpty
        ? createdAt
        : history.transitions.last.occurredAt.toUtc();
    if (referenceTime.isAfter(now)) {
      throw StateError('Decision outcome cannot be evaluated in the future.');
    }

    final evidenceIds = <String>{...history.record.evidenceIds};
    for (final transition in history.transitions) {
      evidenceIds.addAll(transition.evidenceIds);
    }

    if (history.currentState == DecisionOutcomeState.pending) {
      return DecisionMemoryRetentionDecision(
        recordId: history.record.id,
        disposition: DecisionMemoryRetentionDisposition.active,
        evaluatedAt: now,
        referenceTime: referenceTime,
        reason: 'Pending decisions remain active.',
        evidenceIds: evidenceIds,
      );
    }

    final terminalAge = now.difference(referenceTime);
    final disposition = terminalAge > policy.terminalGracePeriod
        ? DecisionMemoryRetentionDisposition.auditArchive
        : DecisionMemoryRetentionDisposition.active;
    final reason = disposition == DecisionMemoryRetentionDisposition.active
        ? 'Terminal decision remains inside the configured grace period.'
        : 'Terminal decision exceeded the configured grace period and is '
              'moved intact to the audit archive.';

    return DecisionMemoryRetentionDecision(
      recordId: history.record.id,
      disposition: disposition,
      evaluatedAt: now,
      referenceTime: referenceTime,
      reason: reason,
      evidenceIds: evidenceIds,
    );
  }

  DecisionMemoryCompaction compact({
    required DecisionMemory memory,
    required DateTime evaluatedAt,
    required DecisionMemoryRetentionPolicy policy,
  }) {
    final source = codec.export(memory);
    final historiesById = <String, DecisionMemoryHistory>{
      for (final history in memory.all) history.record.id: history,
    };
    final active = <DecisionMemoryArchiveEntry>[];
    final audit = <DecisionMemoryArchiveEntry>[];
    final decisions = <DecisionMemoryRetentionDecision>[];

    for (final entry in source.entries) {
      final history = historiesById[entry.record.id];
      if (history == null) {
        throw StateError('Archive entry has no Decision Memory history.');
      }
      final decision = evaluate(
        history: history,
        evaluatedAt: evaluatedAt,
        policy: policy,
      );
      decisions.add(decision);
      if (decision.disposition == DecisionMemoryRetentionDisposition.active) {
        active.add(entry);
      } else {
        audit.add(entry);
      }
    }

    return DecisionMemoryCompaction(
      activeArchive: DecisionMemoryArchive(
        schemaVersion: DecisionMemoryArchive.currentSchemaVersion,
        entries: active,
      ),
      auditArchive: DecisionMemoryArchive(
        schemaVersion: DecisionMemoryArchive.currentSchemaVersion,
        entries: audit,
      ),
      decisions: decisions,
    );
  }
}
