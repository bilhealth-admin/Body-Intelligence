import '../domain/decision_memory_archive.dart';
import '../domain/decision_memory_compaction.dart';
import '../domain/decision_memory_record.dart';
import '../domain/decision_outcome_transition.dart';
import 'decision_memory.dart';
import 'decision_memory_archive_codec.dart';

/// Integrity gate proving that compaction preserves complete audit evidence.
final class DecisionMemoryCompactionValidator {
  const DecisionMemoryCompactionValidator({
    this.codec = const DecisionMemoryArchiveCodec(),
  });

  final DecisionMemoryArchiveCodec codec;

  DecisionMemoryCompactionIntegrityResult validate({
    required DecisionMemory source,
    required DecisionMemoryCompaction compaction,
  }) {
    final issues = <String>[];
    final sourceEntries = codec.export(source).entries;
    final compactedEntries = <DecisionMemoryArchiveEntry>[
      ...compaction.activeArchive.entries,
      ...compaction.auditArchive.entries,
    ];

    final sourceById = <String, DecisionMemoryArchiveEntry>{};
    for (final entry in sourceEntries) {
      sourceById[entry.record.id] = entry;
    }
    final compactedById = <String, DecisionMemoryArchiveEntry>{};
    for (final entry in compactedEntries) {
      if (compactedById.containsKey(entry.record.id)) {
        issues.add('duplicate-record:${entry.record.id}');
      }
      compactedById[entry.record.id] = entry;
    }

    for (final sourceEntry in sourceEntries) {
      final compacted = compactedById[sourceEntry.record.id];
      if (compacted == null) {
        issues.add('missing-record:${sourceEntry.record.id}');
        continue;
      }
      if (!_sameEntry(sourceEntry, compacted)) {
        issues.add('mutated-record:${sourceEntry.record.id}');
      }
    }
    for (final recordId in compactedById.keys) {
      if (!sourceById.containsKey(recordId)) {
        issues.add('unknown-record:$recordId');
      }
    }

    final decisionIds = compaction.decisions
        .map((decision) => decision.recordId)
        .toList(growable: false);
    if (decisionIds.toSet().length != decisionIds.length) {
      issues.add('duplicate-retention-decision');
    }
    if (decisionIds.toSet().difference(sourceById.keys.toSet()).isNotEmpty ||
        sourceById.keys.toSet().difference(decisionIds.toSet()).isNotEmpty) {
      issues.add('incomplete-retention-decisions');
    }

    return DecisionMemoryCompactionIntegrityResult(
      isValid: issues.isEmpty,
      issues: issues,
    );
  }

  bool _sameEntry(
    DecisionMemoryArchiveEntry left,
    DecisionMemoryArchiveEntry right,
  ) {
    return _sameRecord(left.record, right.record) &&
        _sameTransitions(left.transitions, right.transitions);
  }

  bool _sameRecord(DecisionMemoryRecord left, DecisionMemoryRecord right) {
    return left.id == right.id &&
        left.createdAt.toUtc() == right.createdAt.toUtc() &&
        left.decisionKey == right.decisionKey &&
        left.selectedAction == right.selectedAction &&
        left.rationale == right.rationale &&
        left.confidence == right.confidence &&
        _sameStrings(left.evidenceIds, right.evidenceIds) &&
        left.outcomeState == right.outcomeState;
  }

  bool _sameTransitions(
    List<DecisionOutcomeTransition> left,
    List<DecisionOutcomeTransition> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      final a = left[index];
      final b = right[index];
      if (a.id != b.id ||
          a.decisionRecordId != b.decisionRecordId ||
          a.occurredAt.toUtc() != b.occurredAt.toUtc() ||
          a.fromState != b.fromState ||
          a.toState != b.toState ||
          a.reason != b.reason ||
          !_sameStrings(a.evidenceIds, b.evidenceIds)) {
        return false;
      }
    }
    return true;
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
