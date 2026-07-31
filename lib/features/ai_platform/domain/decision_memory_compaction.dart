import 'dart:collection';

import 'decision_memory_archive.dart';
import 'decision_memory_retention.dart';

/// Lossless split of Decision Memory into active and immutable audit archives.
final class DecisionMemoryCompaction {
  DecisionMemoryCompaction({
    required this.activeArchive,
    required this.auditArchive,
    required Iterable<DecisionMemoryRetentionDecision> decisions,
  }) : decisions = UnmodifiableListView<DecisionMemoryRetentionDecision>(
         decisions.toList(growable: false),
       );

  final DecisionMemoryArchive activeArchive;
  final DecisionMemoryArchive auditArchive;
  final UnmodifiableListView<DecisionMemoryRetentionDecision> decisions;

  int get totalEntryCount =>
      activeArchive.entries.length + auditArchive.entries.length;
}

/// Explainable integrity result for a proposed compaction.
final class DecisionMemoryCompactionIntegrityResult {
  DecisionMemoryCompactionIntegrityResult({
    required this.isValid,
    required Iterable<String> issues,
  }) : issues = UnmodifiableListView<String>(issues.toSet().toList()..sort());

  final bool isValid;
  final UnmodifiableListView<String> issues;
}
