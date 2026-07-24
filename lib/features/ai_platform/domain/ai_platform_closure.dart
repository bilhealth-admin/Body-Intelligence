import 'dart:collection';

/// Stable engine identifiers required for formal AI Platform closure.
enum AiPlatformEngineId {
  truthEngine,
  explainEngine,
  bodyTwin,
  decisionMemory,
  aiContext,
  tissueWaterNoiseIsolation,
  adaptiveMetabolicForecasting,
  oneBestAction,
  aiSafetyLayer,
  automatedHealthInsightSummaries,
  aiCoach,
  promptEngine,
  aiCostOptimizer,
  proprietaryBilIntelligence,
  scientificValidationExplainability,
}

/// Stable engine-level closure classifications.
enum AiPlatformEngineClosureStatus { closed, incomplete, blocked }

/// Immutable evidence that one independent engine satisfies its local closure
/// contract.
final class AiPlatformEngineCheckpoint {
  AiPlatformEngineCheckpoint({
    required this.engineId,
    required this.status,
    required this.contractVersion,
    required Iterable<String> evidenceIds,
    required Iterable<String> limitations,
  }) : evidenceIds = UnmodifiableListView<String>(
         (evidenceIds
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       ),
       limitations = UnmodifiableListView<String>(
         (limitations
             .map((value) => value.trim())
             .where((value) => value.isNotEmpty)
             .toSet()
             .toList()
           ..sort()),
       ) {
    if (contractVersion.trim().isEmpty) {
      throw ArgumentError.value(
        contractVersion,
        'contractVersion',
        'must not be empty',
      );
    }
  }

  final AiPlatformEngineId engineId;
  final AiPlatformEngineClosureStatus status;
  final String contractVersion;
  final List<String> evidenceIds;
  final List<String> limitations;

  bool get isClosed =>
      status == AiPlatformEngineClosureStatus.closed && evidenceIds.isNotEmpty;
}

/// Immutable request to evaluate formal AI Platform closure.
final class AiPlatformClosureRequest {
  AiPlatformClosureRequest({
    required DateTime evaluatedAt,
    required Iterable<AiPlatformEngineCheckpoint> checkpoints,
  }) : evaluatedAt = evaluatedAt.toUtc(),
       checkpoints = UnmodifiableListView<AiPlatformEngineCheckpoint>(
         checkpoints.toList(growable: false),
       );

  final DateTime evaluatedAt;
  final List<AiPlatformEngineCheckpoint> checkpoints;
}

/// Stable final platform closure classifications.
enum AiPlatformClosureStatus { closed, incomplete, rejected }

/// Immutable formal closure certificate for the local AI Platform boundary.
final class AiPlatformClosureResult {
  AiPlatformClosureResult({
    required this.status,
    required DateTime evaluatedAt,
    required Iterable<AiPlatformEngineCheckpoint> checkpoints,
    required Iterable<AiPlatformEngineId> missingEngines,
    required Iterable<AiPlatformEngineId> nonClosedEngines,
    required Iterable<String> integrityIssues,
  }) : evaluatedAt = evaluatedAt.toUtc(),
       checkpoints = UnmodifiableListView<AiPlatformEngineCheckpoint>(
         checkpoints.toList(growable: false),
       ),
       missingEngines = UnmodifiableListView<AiPlatformEngineId>(
         missingEngines.toList(growable: false),
       ),
       nonClosedEngines = UnmodifiableListView<AiPlatformEngineId>(
         nonClosedEngines.toList(growable: false),
       ),
       integrityIssues = UnmodifiableListView<String>(
         (integrityIssues.toSet().toList()..sort()),
       );

  final AiPlatformClosureStatus status;
  final DateTime evaluatedAt;
  final List<AiPlatformEngineCheckpoint> checkpoints;
  final List<AiPlatformEngineId> missingEngines;
  final List<AiPlatformEngineId> nonClosedEngines;
  final List<String> integrityIssues;

  bool get isClosed => status == AiPlatformClosureStatus.closed;
}
