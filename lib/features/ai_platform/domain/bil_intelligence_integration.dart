import 'dart:collection';

import 'one_best_action.dart';

enum BilIntegrationStatus { accepted, abstained, rejected }

enum BilIntegrationSource {
  aiContext,
  bodyTwin,
  decisionMemory,
  adaptiveForecast,
  tissueWater,
  oneBestAction,
  safety,
  coach,
  healthInsight,
  proprietaryIntelligence,
  scientificValidation,
}

final class BilIntegrationSignal {
  BilIntegrationSignal({
    required this.source,
    required this.confidence,
    required this.accepted,
    required this.critical,
    required Iterable<String> evidenceIds,
    required Iterable<String> reasons,
  }) : evidenceIds = UnmodifiableListView<String>(
         (evidenceIds
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       ),
       reasons = UnmodifiableListView<String>(
         (reasons
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       ) {
    if (confidence < 0 || confidence > 1) {
      throw ArgumentError.value(confidence, 'confidence', 'must be in [0, 1]');
    }
  }

  final BilIntegrationSource source;
  final double confidence;
  final bool accepted;
  final bool critical;
  final List<String> evidenceIds;
  final List<String> reasons;
}

final class BilDecisionTraceEntry {
  BilDecisionTraceEntry({
    required this.sequence,
    required this.code,
    required this.statement,
    required Iterable<String> evidenceIds,
  }) : evidenceIds = UnmodifiableListView<String>(
         (evidenceIds.toSet().toList()..sort()),
       );

  final int sequence;
  final String code;
  final String statement;
  final List<String> evidenceIds;
}

final class UnifiedHealthBrainResult {
  UnifiedHealthBrainResult({
    required this.status,
    required DateTime generatedAt,
    required this.confidence,
    required this.selectedAction,
    required Iterable<BilIntegrationSignal> signals,
    required Iterable<String> evidenceIds,
    required Iterable<String> reconciliationIssues,
    required Iterable<String> explanation,
    required Iterable<BilDecisionTraceEntry> decisionTrace,
  }) : generatedAt = generatedAt.toUtc(),
       signals = UnmodifiableListView<BilIntegrationSignal>(
         signals.toList(growable: false),
       ),
       evidenceIds = UnmodifiableListView<String>(
         (evidenceIds.toSet().toList()..sort()),
       ),
       reconciliationIssues = UnmodifiableListView<String>(
         (reconciliationIssues.toSet().toList()..sort()),
       ),
       explanation = UnmodifiableListView<String>(
         explanation.toList(growable: false),
       ),
       decisionTrace = UnmodifiableListView<BilDecisionTraceEntry>(
         (decisionTrace.toList(growable: false)
           ..sort((left, right) => left.sequence.compareTo(right.sequence))),
       ) {
    if (confidence < 0 || confidence > 1) {
      throw ArgumentError.value(confidence, 'confidence', 'must be in [0, 1]');
    }
  }

  final BilIntegrationStatus status;
  final DateTime generatedAt;
  final double confidence;
  final OneBestActionCandidate? selectedAction;
  final List<BilIntegrationSignal> signals;
  final List<String> evidenceIds;
  final List<String> reconciliationIssues;
  final List<String> explanation;
  final List<BilDecisionTraceEntry> decisionTrace;

  bool get canProceed =>
      status == BilIntegrationStatus.accepted &&
      selectedAction != null &&
      reconciliationIssues.isEmpty;
}
