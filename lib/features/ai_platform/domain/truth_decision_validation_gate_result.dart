import 'truth_decision_gate_result.dart';
import 'truth_decision_integrity_result.dart';

/// Integrity status of one truth-decision output after fidelity validation.
enum TruthDecisionValidationGateStatus { accepted, rejected }

/// Immutable post-decision gate that preserves both the original decision
/// result and every explainable fidelity issue found by validation.
///
/// An integrity-accepted upstream rejection remains a safe rejection: no
/// decision is exposed. A decision can be exposed only when the upstream gate
/// produced one and the decision-fidelity validation is valid.
final class TruthDecisionValidationGateResult<T> {
  TruthDecisionValidationGateResult._({
    required this.decisionResult,
    required this.integrity,
    required this.status,
  });

  factory TruthDecisionValidationGateResult.from({
    required TruthDecisionGateResult<T> decisionResult,
    required TruthDecisionIntegrityResult integrity,
  }) {
    return TruthDecisionValidationGateResult<T>._(
      decisionResult: decisionResult,
      integrity: integrity,
      status: integrity.isValid
          ? TruthDecisionValidationGateStatus.accepted
          : TruthDecisionValidationGateStatus.rejected,
    );
  }

  final TruthDecisionGateResult<T> decisionResult;
  final TruthDecisionIntegrityResult integrity;
  final TruthDecisionValidationGateStatus status;

  bool get isIntegrityAccepted =>
      status == TruthDecisionValidationGateStatus.accepted;

  bool get isIntegrityRejected =>
      status == TruthDecisionValidationGateStatus.rejected;

  bool get canExposeDecision =>
      isIntegrityAccepted && decisionResult.canProceed;

  bool get isSafeUpstreamRejection =>
      isIntegrityAccepted && decisionResult.isRejected;
}
