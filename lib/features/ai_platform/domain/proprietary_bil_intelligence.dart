enum BilIntelligenceStatus { approved, abstained, rejected }

enum BilIntelligenceSignalKind {
  factualState,
  forecast,
  action,
  safety,
  insight,
}

final class BilIntelligenceSignal {
  BilIntelligenceSignal({
    required this.id,
    required this.kind,
    required this.statement,
    required this.confidence,
    required Iterable<String> evidenceIds,
  }) : evidenceIds = List.unmodifiable(evidenceIds);

  final String id;
  final BilIntelligenceSignalKind kind;
  final String statement;
  final double confidence;
  final List<String> evidenceIds;
}

final class ProprietaryBilIntelligenceRequest {
  ProprietaryBilIntelligenceRequest({
    required DateTime generatedAt,
    required Iterable<BilIntelligenceSignal> signals,
    required Iterable<String> requiredSignalIds,
  }) : generatedAt = generatedAt.toUtc(),
       signals = List.unmodifiable(signals),
       requiredSignalIds = List.unmodifiable(requiredSignalIds);

  final DateTime generatedAt;
  final List<BilIntelligenceSignal> signals;
  final List<String> requiredSignalIds;
}

final class ProprietaryBilIntelligenceResult {
  ProprietaryBilIntelligenceResult({
    required this.status,
    required DateTime generatedAt,
    required this.summary,
    required Iterable<String> signalIds,
    required Iterable<String> evidenceIds,
    required Iterable<String> issues,
  }) : generatedAt = generatedAt.toUtc(),
       signalIds = List.unmodifiable(signalIds),
       evidenceIds = List.unmodifiable(evidenceIds),
       issues = List.unmodifiable(issues);

  final BilIntelligenceStatus status;
  final DateTime generatedAt;
  final String summary;
  final List<String> signalIds;
  final List<String> evidenceIds;
  final List<String> issues;

  bool get canProceed => status == BilIntelligenceStatus.approved;
}
