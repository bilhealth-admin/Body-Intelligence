import '../domain/truth_decision_candidate.dart';
import '../domain/truth_explain_foundation_result.dart';
import '../domain/truth_proposition.dart';
import '../domain/truth_rule.dart';
import 'trusted_truth_decision_pipeline.dart';

/// Stable public API for the completed deterministic Truth/Explain foundation.
///
/// The facade delegates all evaluation and integrity enforcement to the
/// established trusted pipeline. It adds no policy, ranking, provider access,
/// persistence, clock access, randomness, or state mutation.
final class TruthExplainFoundation {
  const TruthExplainFoundation({
    this.pipeline = const TrustedTruthDecisionPipeline(),
  });

  final TrustedTruthDecisionPipeline pipeline;

  TruthExplainFoundationResult<A> evaluate<C, A>({
    required TruthProposition<C> proposition,
    required C context,
    required Iterable<TruthRule<C>> rules,
    required TruthDecisionCandidate<A> supportedCandidate,
    required TruthDecisionCandidate<A> contradictedCandidate,
  }) {
    return TruthExplainFoundationResult<A>.fromTrusted(
      pipeline.evaluate<C, A>(
        proposition: proposition,
        context: context,
        rules: rules,
        supportedCandidate: supportedCandidate,
        contradictedCandidate: contradictedCandidate,
      ),
    );
  }
}
