import '../domain/truth_decision_candidate.dart';
import '../domain/truth_proposition.dart';
import '../domain/truth_rule.dart';
import '../domain/trusted_truth_decision_result.dart';
import 'truth_decision_pipeline.dart';
import 'truth_decision_pipeline_integrity_gate.dart';

/// Final local orchestration boundary for the trusted Truth/Explain foundation.
///
/// It delegates evaluation to [TruthDecisionPipeline] and delegates envelope
/// integrity to [TruthDecisionPipelineIntegrityGate]. It adds no inference,
/// ranking, persistence, provider access, network access, clock access,
/// randomness, or user-state mutation.
final class TrustedTruthDecisionPipeline {
  const TrustedTruthDecisionPipeline({
    this.pipeline = const TruthDecisionPipeline(),
    this.integrityGate = const TruthDecisionPipelineIntegrityGate(),
  });

  final TruthDecisionPipeline pipeline;
  final TruthDecisionPipelineIntegrityGate integrityGate;

  TrustedTruthDecisionResult<A> evaluate<C, A>({
    required TruthProposition<C> proposition,
    required C context,
    required Iterable<TruthRule<C>> rules,
    required TruthDecisionCandidate<A> supportedCandidate,
    required TruthDecisionCandidate<A> contradictedCandidate,
  }) {
    final pipelineResult = pipeline.evaluate<C, A>(
      proposition: proposition,
      context: context,
      rules: rules,
      supportedCandidate: supportedCandidate,
      contradictedCandidate: contradictedCandidate,
    );
    return TrustedTruthDecisionResult<A>(
      gate: integrityGate.evaluate(pipelineResult),
    );
  }
}
