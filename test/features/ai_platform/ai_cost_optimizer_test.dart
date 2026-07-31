import 'package:body_intelligence_log/features/ai_platform/domain/ai_cost_optimization.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_cost_optimizer_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_cost_optimizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers deterministic local execution by default', () {
    final result = const AiCostOptimizer().optimize(
      AiCostOptimizationRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        requiresRemoteCapability: true,
        inputCharacters: 100,
        requestedOutputCharacters: 200,
        remoteRequestsUsed: 0,
        evidenceIds: const ['truth-1'],
      ),
    );

    expect(result.canProceed, isTrue);
    expect(result.route, AiExecutionRoute.local);
    expect(result.evidenceIds, ['truth-1']);
  });

  test(
    'permits remote route only when explicitly allowed and within budget',
    () {
      final optimizer = AiCostOptimizer(
        policy: const AiCostOptimizerPolicy(localFirst: false),
      );
      final result = optimizer.optimize(
        AiCostOptimizationRequest(
          generatedAt: DateTime.utc(2026, 7, 24),
          requiresRemoteCapability: true,
          inputCharacters: 100,
          requestedOutputCharacters: 200,
          remoteRequestsUsed: 1,
          evidenceIds: const ['truth-1'],
        ),
      );

      expect(result.canProceed, isTrue);
      expect(result.route, AiExecutionRoute.remote);
    },
  );
}
