import '../domain/truth_decision_candidate.dart';
import '../domain/truth_decision_gate_result.dart';
import '../domain/truth_evaluation_report.dart';
import 'truth_decision_explainer.dart';
import 'truth_evaluation_gate.dart';

/// Pure local pipeline that integrity-gates a truth report before any
/// explainable decision is produced.
///
/// Rejected reports are preserved for diagnostics and never forwarded to the
/// decision explainer. Accepted reports retain the established deterministic
/// selection and abstention behavior of [TruthDecisionExplainer].
final class TruthDecisionGate {
  const TruthDecisionGate({
    this.evaluationGate = const TruthEvaluationGate(),
    this.explainer = const TruthDecisionExplainer(),
  });

  final TruthEvaluationGate evaluationGate;
  final TruthDecisionExplainer explainer;

  TruthDecisionGateResult<T> evaluate<T>({
    required TruthEvaluationReport report,
    required TruthDecisionCandidate<T> supportedCandidate,
    required TruthDecisionCandidate<T> contradictedCandidate,
  }) {
    final gate = evaluationGate.evaluate(report);
    if (!gate.canProceed) {
      return TruthDecisionGateResult<T>.rejected(gate: gate);
    }

    return TruthDecisionGateResult<T>.accepted(
      gate: gate,
      decision: explainer.explain(
        assessment: report.assessment,
        supportedCandidate: supportedCandidate,
        contradictedCandidate: contradictedCandidate,
      ),
    );
  }
}
