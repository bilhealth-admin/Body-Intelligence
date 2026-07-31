import 'dart:collection';

import 'body_twin_snapshot.dart';
import 'body_twin_trend_state.dart';
import 'decision_memory_history.dart';
import 'truth_explain_foundation_result.dart';

/// Stable source classifications for facts admitted into AI Context.
enum AiContextSource { truthExplain, bodyTwin, decisionMemory }

/// Immutable provenance for one admitted context component.
final class AiContextProvenance {
  AiContextProvenance({
    required this.contextKey,
    required this.source,
    required Iterable<String> evidenceIds,
  }) : evidenceIds = UnmodifiableListView<String>(
         (evidenceIds
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       ) {
    if (contextKey.trim().isEmpty) {
      throw ArgumentError.value(contextKey, 'contextKey', 'must not be empty');
    }
  }

  final String contextKey;
  final AiContextSource source;
  final List<String> evidenceIds;
}

/// Immutable, bounded, provider-neutral context assembled from accepted local
/// engine outputs only.
final class AiContext<T> {
  AiContext({
    required DateTime asOf,
    required this.truthStatus,
    required this.truthDecision,
    required this.bodySnapshot,
    required this.bodyTrends,
    required Iterable<DecisionMemoryHistory> decisionHistory,
    required Iterable<String> missingContextKeys,
    required Iterable<AiContextProvenance> provenance,
  }) : asOf = asOf.toUtc(),
       decisionHistory = UnmodifiableListView<DecisionMemoryHistory>(
         decisionHistory.toList(growable: false),
       ),
       missingContextKeys = UnmodifiableListView<String>(
         (missingContextKeys.toSet().toList()..sort()),
       ),
       provenance = UnmodifiableListView<AiContextProvenance>(
         (provenance.toList(
           growable: false,
         )..sort((left, right) => left.contextKey.compareTo(right.contextKey))),
       );

  final DateTime asOf;
  final TruthExplainFoundationStatus truthStatus;
  final T? truthDecision;
  final BodyTwinSnapshot? bodySnapshot;
  final BodyTwinTrendState? bodyTrends;
  final List<DecisionMemoryHistory> decisionHistory;
  final List<String> missingContextKeys;
  final List<AiContextProvenance> provenance;

  bool get isComplete => missingContextKeys.isEmpty;
}

/// Stable closure classifications for AI Context Engine.
enum AiContextEngineStatus { accepted, incomplete, rejected }

/// Immutable public result of AI Context Engine.
final class AiContextEngineResult<T> {
  AiContextEngineResult({
    required this.context,
    required Iterable<String> integrityIssues,
    required this.upstreamRejected,
  }) : integrityIssues = UnmodifiableListView<String>(
         (integrityIssues.toSet().toList()..sort()),
       );

  final AiContext<T> context;
  final List<String> integrityIssues;
  final bool upstreamRejected;

  AiContextEngineStatus get status {
    if (upstreamRejected || integrityIssues.isNotEmpty) {
      return AiContextEngineStatus.rejected;
    }
    if (!context.isComplete) {
      return AiContextEngineStatus.incomplete;
    }
    return AiContextEngineStatus.accepted;
  }

  bool get canProceed => status == AiContextEngineStatus.accepted;

  AiContext<T>? get acceptedContext => canProceed ? context : null;
}
