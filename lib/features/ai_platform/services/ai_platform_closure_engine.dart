import '../domain/ai_platform_closure.dart';
import '../domain/ai_platform_closure_policy.dart';
import 'ai_platform_closure_integrity_validator.dart';

/// Final deterministic integration boundary for the local AI Platform.
///
/// This engine does not orchestrate, merge, or reimplement independent engine
/// behavior. It reconciles explicit engine-level closure evidence and emits a
/// formal closure result only when every required engine is present, closed,
/// and integrity-valid.
final class AiPlatformClosureEngine {
  const AiPlatformClosureEngine({
    this.validator = const AiPlatformClosureIntegrityValidator(),
  });

  final AiPlatformClosureIntegrityValidator validator;

  AiPlatformClosureResult evaluate(AiPlatformClosureRequest request) {
    final integrityIssues = validator.validate(request);
    final byEngine = <AiPlatformEngineId, AiPlatformEngineCheckpoint>{};

    for (final checkpoint in request.checkpoints) {
      byEngine.putIfAbsent(checkpoint.engineId, () => checkpoint);
    }

    final missingEngines =
        AiPlatformClosurePolicy.requiredEngines
            .where((engineId) => !byEngine.containsKey(engineId))
            .toList(growable: false)
          ..sort((left, right) => left.index.compareTo(right.index));

    final nonClosedEngines =
        AiPlatformClosurePolicy.requiredEngines
            .where(
              (engineId) =>
                  byEngine.containsKey(engineId) &&
                  !byEngine[engineId]!.isClosed,
            )
            .toList(growable: false)
          ..sort((left, right) => left.index.compareTo(right.index));

    final orderedCheckpoints = byEngine.values.toList(growable: false)
      ..sort(
        (left, right) => left.engineId.index.compareTo(right.engineId.index),
      );

    final status = integrityIssues.isNotEmpty
        ? AiPlatformClosureStatus.rejected
        : missingEngines.isNotEmpty || nonClosedEngines.isNotEmpty
        ? AiPlatformClosureStatus.incomplete
        : AiPlatformClosureStatus.closed;

    return AiPlatformClosureResult(
      status: status,
      evaluatedAt: request.evaluatedAt,
      checkpoints: orderedCheckpoints,
      missingEngines: missingEngines,
      nonClosedEngines: nonClosedEngines,
      integrityIssues: integrityIssues,
    );
  }
}
