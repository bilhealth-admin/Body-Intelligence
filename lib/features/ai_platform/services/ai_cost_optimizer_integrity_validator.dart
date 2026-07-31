import '../domain/ai_cost_optimization.dart';

final class AiCostOptimizerIntegrityValidator {
  const AiCostOptimizerIntegrityValidator();

  List<String> validateRequest(AiCostOptimizationRequest request) {
    final issues = <String>[];
    if (request.inputCharacters < 0) {
      issues.add('inputCharacters must not be negative.');
    }
    if (request.requestedOutputCharacters < 0) {
      issues.add('requestedOutputCharacters must not be negative.');
    }
    if (request.remoteRequestsUsed < 0) {
      issues.add('remoteRequestsUsed must not be negative.');
    }
    if (request.evidenceIds.any((value) => value.trim().isEmpty)) {
      issues.add('evidenceIds must not contain blank values.');
    }
    return List.unmodifiable(issues);
  }

  List<String> validateDecision(AiCostOptimizationDecision decision) {
    final issues = <String>[];
    if (decision.reason.trim().isEmpty) {
      issues.add('reason must not be blank.');
    }
    if (decision.allowedOutputCharacters < 0) {
      issues.add('allowedOutputCharacters must not be negative.');
    }
    if (!decision.canProceed && decision.route != AiExecutionRoute.abstain) {
      issues.add('non-approved decisions must abstain.');
    }
    return List.unmodifiable(issues);
  }
}
