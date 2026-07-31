import 'package:body_intelligence_log/features/ai_platform/domain/ai_platform_closure.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_platform_closure_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_platform_closure_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = AiPlatformClosureEngine();

  test('rejects duplicate engine evidence deterministically', () {
    final duplicate = AiPlatformEngineCheckpoint(
      engineId: AiPlatformEngineId.truthEngine,
      status: AiPlatformEngineClosureStatus.closed,
      contractVersion: '1.0.0',
      evidenceIds: const ['truth:test'],
      limitations: const [],
    );

    final checkpoints = <AiPlatformEngineCheckpoint>[
      ...AiPlatformClosurePolicy.requiredEngines.map(
        (engineId) => AiPlatformEngineCheckpoint(
          engineId: engineId,
          status: AiPlatformEngineClosureStatus.closed,
          contractVersion: '1.0.0',
          evidenceIds: ['test:${engineId.name}'],
          limitations: const [],
        ),
      ),
      duplicate,
    ];

    final result = engine.evaluate(
      AiPlatformClosureRequest(
        evaluatedAt: DateTime.utc(2026, 7, 24),
        checkpoints: checkpoints.reversed,
      ),
    );

    expect(result.status, AiPlatformClosureStatus.rejected);
    expect(result.integrityIssues, ['duplicate_engine:truthEngine']);
    expect(
      result.checkpoints.map((checkpoint) => checkpoint.engineId),
      orderedEquals(AiPlatformEngineId.values),
    );
  });

  test('a closed label without evidence cannot close the platform', () {
    final result = engine.evaluate(
      AiPlatformClosureRequest(
        evaluatedAt: DateTime.utc(2026, 7, 24),
        checkpoints: AiPlatformClosurePolicy.requiredEngines.map(
          (engineId) => AiPlatformEngineCheckpoint(
            engineId: engineId,
            status: AiPlatformEngineClosureStatus.closed,
            contractVersion: '1.0.0',
            evidenceIds: engineId == AiPlatformEngineId.explainEngine
                ? const []
                : ['test:${engineId.name}'],
            limitations: const [],
          ),
        ),
      ),
    );

    expect(result.status, AiPlatformClosureStatus.rejected);
    expect(result.isClosed, isFalse);
    expect(result.integrityIssues, ['missing_evidence:explainEngine']);
    expect(result.nonClosedEngines, [AiPlatformEngineId.explainEngine]);
  });
}
