import '../domain/truth_decision_gate_result.dart';
import '../domain/truth_decision_validation_gate_result.dart';
import 'truth_decision_validator.dart';

/// Pure local gate that converts truth-decision fidelity validation into an
/// explicit consumption boundary.
///
/// The gate does not repair, replace, rank, persist, or forward decisions. It
/// preserves the original result and exposes whether downstream code may read
/// the decision without bypassing integrity findings.
final class TruthDecisionValidationGate {
  const TruthDecisionValidationGate({
    this.validator = const TruthDecisionValidator(),
  });

  final TruthDecisionValidator validator;

  TruthDecisionValidationGateResult<T> evaluate<T>(
    TruthDecisionGateResult<T> result,
  ) {
    return TruthDecisionValidationGateResult<T>.from(
      decisionResult: result,
      integrity: validator.validate(result),
    );
  }
}
