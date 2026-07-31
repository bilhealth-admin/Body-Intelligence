import 'package:body_intelligence_log/features/ai_platform/domain/ai_cost_optimization.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_cost_optimizer_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_cost_optimizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('abstains deterministically when any budget is exceeded', () {
    final optimizer = AiCostOptimizer(
      policy: const AiCostOptimizerPolicy(
        localFirst: false,
        budget: AiCostBudget(
          maximumRemoteRequests: 1,
          maximumInputCharacters: 10,
          maximumOutputCharacters: 20,
        ),
      ),
    );

    for (final request in <AiCostOptimizationRequest>[
      AiCostOptimizationRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        requiresRemoteCapability: true,
        inputCharacters: 11,
        requestedOutputCharacters: 10,
        remoteRequestsUsed: 0,
        evidenceIds: const ['e1'],
      ),
      AiCostOptimizationRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        requiresRemoteCapability: true,
        inputCharacters: 10,
        requestedOutputCharacters: 21,
        remoteRequestsUsed: 0,
        evidenceIds: const ['e1'],
      ),
      AiCostOptimizationRequest(
        generatedAt: DateTime.utc(2026, 7, 24),
        requiresRemoteCapability: true,
        inputCharacters: 10,
        requestedOutputCharacters: 20,
        remoteRequestsUsed: 1,
        evidenceIds: const ['e1'],
      ),
    ]) {
      final result = optimizer.optimize(request);
      expect(result.canProceed, isFalse);
      expect(result.route, AiExecutionRoute.abstain);
      expect(result.allowedOutputCharacters, 0);
    }
  });

  test('collections are immutable', () {
    final request = AiCostOptimizationRequest(
      generatedAt: DateTime.utc(2026, 7, 24),
      requiresRemoteCapability: false,
      inputCharacters: 1,
      requestedOutputCharacters: 1,
      remoteRequestsUsed: 0,
      evidenceIds: const ['e1'],
    );
    expect(() => request.evidenceIds.add('e2'), throwsUnsupportedError);
  });
}
