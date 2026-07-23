import 'truth_decision_validation_gate_result.dart';
import 'truth_evaluation_report.dart';

/// Immutable end-to-end result of one deterministic Truth/Explain evaluation.
///
/// The result preserves the original report and the final validated exposure
/// gate. It performs no inference, persistence, network access, ranking, or
/// user-state mutation.
final class TruthDecisionPipelineResult<T> {
  const TruthDecisionPipelineResult({
    required this.report,
    required this.validation,
  });

  final TruthEvaluationReport report;
  final TruthDecisionValidationGateResult<T> validation;

  bool get canExposeDecision => validation.canExposeDecision;
  bool get isSafeRejection => validation.isSafeUpstreamRejection;
}
