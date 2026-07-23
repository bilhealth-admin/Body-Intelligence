import '../domain/truth_decision_pipeline_integrity_result.dart';
import '../domain/truth_decision_pipeline_result.dart';

/// Pure local validator for the trusted Truth/Explain pipeline envelope.
///
/// It performs no inference and never repairs or replaces output. It verifies
/// that the pipeline preserves the exact report instance used by the decision
/// gates and that exposure state cannot contradict the validated decision.
final class TruthDecisionPipelineValidator {
  const TruthDecisionPipelineValidator();

  TruthDecisionPipelineIntegrityResult validate<T>(
    TruthDecisionPipelineResult<T> result,
  ) {
    final issues = <TruthDecisionPipelineIntegrityIssue>[];
    final validation = result.validation;
    final decisionResult = validation.decisionResult;

    if (!identical(result.report, decisionResult.gate.report)) {
      issues.add(
        TruthDecisionPipelineIntegrityIssue(
          code: TruthDecisionPipelineIntegrityIssueCode.reportReferenceMismatch,
          message:
              'Pipeline report does not preserve the exact report instance validated by the decision gates.',
        ),
      );
    }

    if (result.canExposeDecision && decisionResult.decision == null) {
      issues.add(
        TruthDecisionPipelineIntegrityIssue(
          code:
              TruthDecisionPipelineIntegrityIssueCode.exposableDecisionMissing,
          message:
              'Pipeline declares an exposable decision but no decision is present.',
        ),
      );
    }

    if (validation.isIntegrityRejected && result.canExposeDecision) {
      issues.add(
        TruthDecisionPipelineIntegrityIssue(
          code: TruthDecisionPipelineIntegrityIssueCode
              .unsafeRejectedValidationExposure,
          message:
              'Pipeline exposes a decision even though decision fidelity validation was rejected.',
        ),
      );
    }

    return TruthDecisionPipelineIntegrityResult(issues: issues);
  }
}
