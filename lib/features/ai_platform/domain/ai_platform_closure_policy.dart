import 'ai_platform_closure.dart';

/// Canonical engine set required for formal local AI Platform closure.
final class AiPlatformClosurePolicy {
  const AiPlatformClosurePolicy();

  static const Set<AiPlatformEngineId> requiredEngines = {
    AiPlatformEngineId.truthEngine,
    AiPlatformEngineId.explainEngine,
    AiPlatformEngineId.bodyTwin,
    AiPlatformEngineId.decisionMemory,
    AiPlatformEngineId.aiContext,
    AiPlatformEngineId.tissueWaterNoiseIsolation,
    AiPlatformEngineId.adaptiveMetabolicForecasting,
    AiPlatformEngineId.oneBestAction,
    AiPlatformEngineId.aiSafetyLayer,
    AiPlatformEngineId.automatedHealthInsightSummaries,
    AiPlatformEngineId.aiCoach,
    AiPlatformEngineId.promptEngine,
    AiPlatformEngineId.aiCostOptimizer,
    AiPlatformEngineId.proprietaryBilIntelligence,
    AiPlatformEngineId.scientificValidationExplainability,
  };
}
