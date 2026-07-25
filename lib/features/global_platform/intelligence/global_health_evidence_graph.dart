import 'dart:collection';

import '../core/global_platform_core.dart';

final class SourceReliabilityProfile {
  const SourceReliabilityProfile({
    required this.sourceKey,
    required this.accepted,
    required this.rejected,
    required this.conflicted,
  });

  final String sourceKey;
  final int accepted;
  final int rejected;
  final int conflicted;

  double get reliability {
    final total = accepted + rejected + conflicted;
    if (total == 0) return 0.5;
    return ((accepted + (conflicted * 0.35)) / total).clamp(0.05, 0.99);
  }
}

final class GlobalEvidenceNode {
  const GlobalEvidenceNode({
    required this.id,
    required this.signal,
    required this.reliability,
    required this.fusedConfidence,
    required this.selected,
    required this.explanation,
  });

  final String id;
  final GlobalHealthSignal signal;
  final double reliability;
  final double fusedConfidence;
  final bool selected;
  final String explanation;
}

final class GlobalEvidenceConflict {
  const GlobalEvidenceConflict({
    required this.key,
    required this.candidateIds,
    required this.selectedId,
    required this.margin,
  });

  final String key;
  final List<String> candidateIds;
  final String selectedId;
  final double margin;
}

final class GlobalHealthEvidenceGraph {
  GlobalHealthEvidenceGraph({
    required Iterable<GlobalEvidenceNode> nodes,
    required Iterable<GlobalEvidenceConflict> conflicts,
  }) : nodes = List<GlobalEvidenceNode>.unmodifiable(nodes),
       conflicts = List<GlobalEvidenceConflict>.unmodifiable(conflicts);

  final List<GlobalEvidenceNode> nodes;
  final List<GlobalEvidenceConflict> conflicts;

  List<GlobalHealthSignal> get selectedSignals =>
      List<GlobalHealthSignal>.unmodifiable(
        nodes.where((node) => node.selected).map((node) => node.signal),
      );

  double get confidence {
    final selected = nodes.where((node) => node.selected).toList();
    if (selected.isEmpty) return 0;
    return selected
            .map((node) => node.fusedConfidence)
            .reduce((a, b) => a + b) /
        selected.length;
  }
}

final class SourceReliabilityMemory {
  SourceReliabilityMemory({required this.store});

  final GlobalDurableStore store;

  Future<SourceReliabilityProfile> read(String sourceKey) async {
    final row = await store.get('global_source_reliability', sourceKey);
    return SourceReliabilityProfile(
      sourceKey: sourceKey,
      accepted: (row?['accepted'] as num? ?? 0).toInt(),
      rejected: (row?['rejected'] as num? ?? 0).toInt(),
      conflicted: (row?['conflicted'] as num? ?? 0).toInt(),
    );
  }

  Future<void> record({
    required String sourceKey,
    required bool accepted,
    required bool conflicted,
  }) async {
    final prior = await read(sourceKey);
    await store.put('global_source_reliability', sourceKey, <String, Object?>{
      'sourceKey': sourceKey,
      'accepted': prior.accepted + (accepted ? 1 : 0),
      'rejected': prior.rejected + (accepted ? 0 : 1),
      'conflicted': prior.conflicted + (conflicted ? 1 : 0),
    });
  }
}

final class BilGlobalHealthEvidenceGraphEngine {
  BilGlobalHealthEvidenceGraphEngine({required this.memory});

  final SourceReliabilityMemory memory;

  Future<GlobalHealthEvidenceGraph> build(
    Iterable<GlobalHealthSignal> source,
  ) async {
    final groups = <String, List<GlobalHealthSignal>>{};
    for (final signal in source.where((signal) => !signal.deleted)) {
      final minute =
          signal.provenance.observedAt.millisecondsSinceEpoch ~/ 60000;
      (groups['${signal.key}:$minute'] ??= <GlobalHealthSignal>[]).add(signal);
    }

    final nodes = <GlobalEvidenceNode>[];
    final conflicts = <GlobalEvidenceConflict>[];
    for (final entry in groups.entries) {
      final candidates =
          <({GlobalHealthSignal signal, double score, double reliability})>[];
      for (final signal in entry.value) {
        final sourceKey =
            '${signal.provenance.providerId}:${signal.provenance.sourceId}';
        final reliability = (await memory.read(sourceKey)).reliability;
        final deviceBonus = signal.provenance.deviceId == null ? 0.0 : 0.025;
        final score =
            (signal.provenance.confidence * 0.7) +
            (reliability * 0.3) +
            deviceBonus;
        candidates.add((
          signal: signal,
          score: score.clamp(0, 1).toDouble(),
          reliability: reliability,
        ));
      }
      candidates.sort((left, right) {
        final score = right.score.compareTo(left.score);
        return score != 0
            ? score
            : left.signal.identity.compareTo(right.signal.identity);
      });
      final selected = candidates.first;
      final margin = candidates.length == 1
          ? selected.score
          : selected.score - candidates[1].score;
      final isConflict = candidates.length > 1;
      if (isConflict) {
        conflicts.add(
          GlobalEvidenceConflict(
            key: entry.key,
            candidateIds: List<String>.unmodifiable(
              candidates.map((candidate) => candidate.signal.identity),
            ),
            selectedId: selected.signal.identity,
            margin: margin,
          ),
        );
      }
      for (final candidate in candidates) {
        final chosen = identical(candidate, selected);
        final sourceKey =
            '${candidate.signal.provenance.providerId}:${candidate.signal.provenance.sourceId}';
        await memory.record(
          sourceKey: sourceKey,
          accepted: chosen,
          conflicted: isConflict,
        );
        nodes.add(
          GlobalEvidenceNode(
            id: candidate.signal.identity,
            signal: candidate.signal,
            reliability: candidate.reliability,
            fusedConfidence: candidate.score,
            selected: chosen,
            explanation: chosen
                ? 'Selected by provenance confidence, learned source reliability, device provenance, and deterministic tie-breaking.'
                : 'Suppressed as a lower-confidence duplicate or conflicting observation.',
          ),
        );
      }
    }
    nodes.sort(
      (left, right) => left.signal.provenance.observedAt.compareTo(
        right.signal.provenance.observedAt,
      ),
    );
    return GlobalHealthEvidenceGraph(nodes: nodes, conflicts: conflicts);
  }
}

final class GlobalEvidenceGraphSnapshot {
  GlobalEvidenceGraphSnapshot({required GlobalHealthEvidenceGraph graph})
    : selectedIds = UnmodifiableListView<String>(
        graph.nodes
            .where((node) => node.selected)
            .map((node) => node.id)
            .toList(),
      ),
      conflictCount = graph.conflicts.length,
      confidence = graph.confidence;

  final List<String> selectedIds;
  final int conflictCount;
  final double confidence;
}
