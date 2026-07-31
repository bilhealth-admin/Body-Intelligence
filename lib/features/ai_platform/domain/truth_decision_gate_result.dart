import 'explainable_ai_decision.dart';
import 'truth_evaluation_gate_result.dart';

/// Outcome of attempting to produce an explainable decision from a gated
/// deterministic truth report.
enum TruthDecisionGateStatus { decisionAvailable, rejected }

/// Immutable boundary that preserves the integrity-gate result and exposes a
/// decision only when the underlying report is valid.
final class TruthDecisionGateResult<T> {
  const TruthDecisionGateResult._({
    required this.gate,
    required this.status,
    required this.decision,
  });

  factory TruthDecisionGateResult.accepted({
    required TruthEvaluationGateResult gate,
    required ExplainableAiDecision<T> decision,
  }) {
    if (!gate.canProceed) {
      throw ArgumentError('An accepted decision requires an accepted gate.');
    }
    return TruthDecisionGateResult<T>._(
      gate: gate,
      status: TruthDecisionGateStatus.decisionAvailable,
      decision: decision,
    );
  }

  factory TruthDecisionGateResult.rejected({
    required TruthEvaluationGateResult gate,
  }) {
    if (gate.canProceed) {
      throw ArgumentError('A rejected decision requires a rejected gate.');
    }
    return TruthDecisionGateResult<T>._(
      gate: gate,
      status: TruthDecisionGateStatus.rejected,
      decision: null,
    );
  }

  final TruthEvaluationGateResult gate;
  final TruthDecisionGateStatus status;
  final ExplainableAiDecision<T>? decision;

  bool get canProceed => status == TruthDecisionGateStatus.decisionAvailable;
  bool get isRejected => status == TruthDecisionGateStatus.rejected;
}
