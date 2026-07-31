import 'explainable_ai_decision.dart';
import 'truth_decision_pipeline_integrity_gate_result.dart';

/// Immutable final result of the locally trusted Truth/Explain pipeline.
///
/// The result preserves the complete integrity-gated pipeline envelope. It
/// exposes no decision unless every established validation boundary accepted
/// the original pipeline result.
final class TrustedTruthDecisionResult<T> {
  const TrustedTruthDecisionResult({required this.gate});

  final TruthDecisionPipelineIntegrityGateResult<T> gate;

  bool get canProceed => gate.canProceed;
  bool get isRejected => gate.isRejected;
  bool get canExposeDecision {
    final decision = gate.pipelineResult.validation.decisionResult.decision;
    return canProceed &&
        gate.pipelineResult.canExposeDecision &&
        decision?.disposition == AiDecisionDisposition.action;
  }

  bool get isSafeRejection => canProceed && gate.pipelineResult.isSafeRejection;

  /// True when the trusted pipeline deliberately abstained after every
  /// integrity boundary accepted the result.
  bool get isSafeAbstention {
    final decision = gate.pipelineResult.validation.decisionResult.decision;
    return canProceed && decision?.disposition == AiDecisionDisposition.abstain;
  }

  T? get decision {
    if (!canExposeDecision) return null;
    return gate.pipelineResult.validation.decisionResult.decision?.value;
  }
}
