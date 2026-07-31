import '../domain/ai_platform_closure.dart';
import '../domain/ai_platform_closure_policy.dart';

/// Deterministic integrity validation for formal AI Platform closure evidence.
final class AiPlatformClosureIntegrityValidator {
  const AiPlatformClosureIntegrityValidator();

  List<String> validate(AiPlatformClosureRequest request) {
    final issues = <String>[];
    final seen = <AiPlatformEngineId>{};

    for (final checkpoint in request.checkpoints) {
      if (!seen.add(checkpoint.engineId)) {
        issues.add('duplicate_engine:${checkpoint.engineId.name}');
      }
      if (checkpoint.contractVersion.trim().isEmpty) {
        issues.add('missing_contract_version:${checkpoint.engineId.name}');
      }
      if (checkpoint.evidenceIds.isEmpty) {
        issues.add('missing_evidence:${checkpoint.engineId.name}');
      }
    }

    final unexpected = seen.difference(AiPlatformClosurePolicy.requiredEngines);
    for (final engineId in unexpected) {
      issues.add('unexpected_engine:${engineId.name}');
    }

    issues.sort();
    return List.unmodifiable(issues);
  }
}
