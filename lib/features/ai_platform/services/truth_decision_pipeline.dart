import '../domain/truth_decision_candidate.dart';
import '../domain/truth_decision_pipeline_result.dart';
import '../domain/truth_proposition.dart';
import '../domain/truth_rule.dart';
import 'truth_decision_gate.dart';
import 'truth_decision_validation_gate.dart';
import 'truth_rule_composer.dart';

/// Pure local orchestration boundary for the completed Truth/Explain chain.
///
/// The pipeline composes typed rules once, integrity-gates the resulting truth
/// report, produces an explainable decision when authorized, and validates the
/// decision before exposure. It does not rank candidates or add policy.
final class TruthDecisionPipeline {
  const TruthDecisionPipeline({
    this.composer = const TruthRuleComposer(),
    this.decisionGate = const TruthDecisionGate(),
    this.validationGate = const TruthDecisionValidationGate(),
  });

  final TruthRuleComposer composer;
  final TruthDecisionGate decisionGate;
  final TruthDecisionValidationGate validationGate;

  TruthDecisionPipelineResult<A> evaluate<C, A>({
    required TruthProposition<C> proposition,
    required C context,
    required Iterable<TruthRule<C>> rules,
    required TruthDecisionCandidate<A> supportedCandidate,
    required TruthDecisionCandidate<A> contradictedCandidate,
  }) {
    final report = composer.report(
      proposition: proposition,
      context: context,
      rules: rules,
    );
    final decisionResult = decisionGate.evaluate(
      report: report,
      supportedCandidate: supportedCandidate,
      contradictedCandidate: contradictedCandidate,
    );
    return TruthDecisionPipelineResult<A>(
      report: report,
      validation: validationGate.evaluate(decisionResult),
    );
  }
}
