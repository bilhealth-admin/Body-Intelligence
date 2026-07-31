import '../domain/ai_cost_optimization.dart';
import '../domain/ai_cost_optimizer_policy.dart';
import 'ai_cost_optimizer_integrity_validator.dart';

/// Deterministic provider-neutral routing and budget gate.
///
/// This engine never calls a provider, reads billing data, or changes the
/// truth-owned decision. It only chooses a permitted execution route.
final class AiCostOptimizer {
  const AiCostOptimizer({
    this.policy = const AiCostOptimizerPolicy(),
    this.integrityValidator = const AiCostOptimizerIntegrityValidator(),
  });

  final AiCostOptimizerPolicy policy;
  final AiCostOptimizerIntegrityValidator integrityValidator;

  AiCostOptimizationDecision optimize(AiCostOptimizationRequest request) {
    final requestIssues = integrityValidator.validateRequest(request);
    if (requestIssues.isNotEmpty) {
      return _validated(
        AiCostOptimizationDecision(
          status: AiCostOptimizationStatus.rejected,
          route: AiExecutionRoute.abstain,
          generatedAt: request.generatedAt,
          reason: requestIssues.join(' '),
          allowedOutputCharacters: 0,
          evidenceIds: request.evidenceIds,
        ),
      );
    }

    final budget = policy.budget;
    if (request.inputCharacters > budget.maximumInputCharacters) {
      return _abstain(request, 'Input budget exceeded.');
    }
    if (request.requestedOutputCharacters > budget.maximumOutputCharacters) {
      return _abstain(request, 'Output budget exceeded.');
    }

    if (!request.requiresRemoteCapability || policy.localFirst) {
      return _validated(
        AiCostOptimizationDecision(
          status: AiCostOptimizationStatus.approved,
          route: AiExecutionRoute.local,
          generatedAt: request.generatedAt,
          reason: request.requiresRemoteCapability
              ? 'Local-first policy selected the deterministic local route.'
              : 'Request is fully supported by the deterministic local route.',
          allowedOutputCharacters: request.requestedOutputCharacters,
          evidenceIds: request.evidenceIds,
        ),
      );
    }

    if (request.remoteRequestsUsed >= budget.maximumRemoteRequests) {
      return _abstain(request, 'Remote request budget exhausted.');
    }

    return _validated(
      AiCostOptimizationDecision(
        status: AiCostOptimizationStatus.approved,
        route: AiExecutionRoute.remote,
        generatedAt: request.generatedAt,
        reason:
            'Remote capability is required and remains within policy budget.',
        allowedOutputCharacters: request.requestedOutputCharacters,
        evidenceIds: request.evidenceIds,
      ),
    );
  }

  AiCostOptimizationDecision _abstain(
    AiCostOptimizationRequest request,
    String reason,
  ) {
    return _validated(
      AiCostOptimizationDecision(
        status: AiCostOptimizationStatus.abstained,
        route: AiExecutionRoute.abstain,
        generatedAt: request.generatedAt,
        reason: reason,
        allowedOutputCharacters: 0,
        evidenceIds: request.evidenceIds,
      ),
    );
  }

  AiCostOptimizationDecision _validated(AiCostOptimizationDecision decision) {
    final issues = integrityValidator.validateDecision(decision);
    if (issues.isEmpty) {
      return decision;
    }
    return AiCostOptimizationDecision(
      status: AiCostOptimizationStatus.rejected,
      route: AiExecutionRoute.abstain,
      generatedAt: decision.generatedAt,
      reason: issues.join(' '),
      allowedOutputCharacters: 0,
      evidenceIds: decision.evidenceIds,
    );
  }
}
