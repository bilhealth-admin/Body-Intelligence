import '../domain/truth_decision_pipeline_integrity_gate_result.dart';
import '../domain/truth_decision_pipeline_result.dart';
import 'truth_decision_pipeline_validator.dart';

/// Explicit local consumption gate for trusted Truth/Explain pipeline results.
///
/// The gate adds no inference, ranking, persistence, provider access, network
/// access, clock access, randomness, or state mutation.
final class TruthDecisionPipelineIntegrityGate {
  const TruthDecisionPipelineIntegrityGate({
    this.validator = const TruthDecisionPipelineValidator(),
  });

  final TruthDecisionPipelineValidator validator;

  TruthDecisionPipelineIntegrityGateResult<T> evaluate<T>(
    TruthDecisionPipelineResult<T> result,
  ) {
    return TruthDecisionPipelineIntegrityGateResult<T>.from(
      pipelineResult: result,
      integrity: validator.validate(result),
    );
  }
}
