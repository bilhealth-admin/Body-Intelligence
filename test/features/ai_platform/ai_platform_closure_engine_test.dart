import 'package:body_intelligence_log/features/ai_platform/domain/ai_platform_closure.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_platform_closure_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_platform_closure_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = AiPlatformClosureEngine();
  final evaluatedAt = DateTime.utc(2026, 7, 24, 7);

  test('closes only when every required independent engine is closed', () {
    final result = engine.evaluate(
      AiPlatformClosureRequest(
        evaluatedAt: evaluatedAt,
        checkpoints: AiPlatformClosurePolicy.requiredEngines.map(
          (engineId) => AiPlatformEngineCheckpoint(
            engineId: engineId,
            status: AiPlatformEngineClosureStatus.closed,
            contractVersion: '1.0.0',
            evidenceIds: ['test:${engineId.name}'],
            limitations: const ['local_boundary_only'],
          ),
        ),
      ),
    );

    expect(result.status, AiPlatformClosureStatus.closed);
    expect(result.isClosed, isTrue);
    expect(result.missingEngines, isEmpty);
    expect(result.nonClosedEngines, isEmpty);
    expect(result.integrityIssues, isEmpty);
    expect(
      result.checkpoints.map((checkpoint) => checkpoint.engineId),
      orderedEquals(AiPlatformEngineId.values),
    );
  });

  test('reports missing and non-closed engines without hiding evidence', () {
    final checkpoints = AiPlatformClosurePolicy.requiredEngines
        .where((engineId) => engineId != AiPlatformEngineId.promptEngine)
        .map(
          (engineId) => AiPlatformEngineCheckpoint(
            engineId: engineId,
            status: engineId == AiPlatformEngineId.aiSafetyLayer
                ? AiPlatformEngineClosureStatus.blocked
                : AiPlatformEngineClosureStatus.closed,
            contractVersion: '1.0.0',
            evidenceIds: ['test:${engineId.name}'],
            limitations: const [],
          ),
        );

    final result = engine.evaluate(
      AiPlatformClosureRequest(
        evaluatedAt: evaluatedAt,
        checkpoints: checkpoints,
      ),
    );

    expect(result.status, AiPlatformClosureStatus.incomplete);
    expect(result.isClosed, isFalse);
    expect(result.missingEngines, [AiPlatformEngineId.promptEngine]);
    expect(result.nonClosedEngines, [AiPlatformEngineId.aiSafetyLayer]);
    expect(result.checkpoints, isNotEmpty);
  });
}
