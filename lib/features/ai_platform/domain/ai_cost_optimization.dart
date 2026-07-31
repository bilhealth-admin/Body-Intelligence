enum AiExecutionRoute { local, remote, abstain }

enum AiCostOptimizationStatus { approved, abstained, rejected }

final class AiCostBudget {
  const AiCostBudget({
    required this.maximumRemoteRequests,
    required this.maximumInputCharacters,
    required this.maximumOutputCharacters,
  });

  final int maximumRemoteRequests;
  final int maximumInputCharacters;
  final int maximumOutputCharacters;
}

final class AiCostOptimizationRequest {
  AiCostOptimizationRequest({
    required DateTime generatedAt,
    required this.requiresRemoteCapability,
    required this.inputCharacters,
    required this.requestedOutputCharacters,
    required this.remoteRequestsUsed,
    required Iterable<String> evidenceIds,
  }) : generatedAt = generatedAt.toUtc(),
       evidenceIds = List.unmodifiable(evidenceIds);

  final DateTime generatedAt;
  final bool requiresRemoteCapability;
  final int inputCharacters;
  final int requestedOutputCharacters;
  final int remoteRequestsUsed;
  final List<String> evidenceIds;
}

final class AiCostOptimizationDecision {
  AiCostOptimizationDecision({
    required this.status,
    required this.route,
    required DateTime generatedAt,
    required this.reason,
    required this.allowedOutputCharacters,
    required Iterable<String> evidenceIds,
  }) : generatedAt = generatedAt.toUtc(),
       evidenceIds = List.unmodifiable(evidenceIds);

  final AiCostOptimizationStatus status;
  final AiExecutionRoute route;
  final DateTime generatedAt;
  final String reason;
  final int allowedOutputCharacters;
  final List<String> evidenceIds;

  bool get canProceed => status == AiCostOptimizationStatus.approved;
}
