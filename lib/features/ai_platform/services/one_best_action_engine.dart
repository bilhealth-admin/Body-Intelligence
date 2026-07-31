import '../domain/adaptive_metabolic_forecast.dart';
import '../domain/ai_context.dart';
import '../domain/one_best_action.dart';
import '../domain/one_best_action_policy.dart';
import 'one_best_action_integrity_validator.dart';

/// Deterministic, provider-neutral ranking boundary.
///
/// Candidate generation and clinical safety policy remain outside this engine.
/// It ranks only caller-supplied, safety-eligible actions supported by accepted
/// local context and forecasting outputs.
final class OneBestActionEngine {
  const OneBestActionEngine({
    this.integrityValidator = const OneBestActionIntegrityValidator(),
  });

  final OneBestActionIntegrityValidator integrityValidator;

  OneBestActionResult select<T>({
    required AiContextEngineResult<T> contextResult,
    required AdaptiveMetabolicForecastResult forecastResult,
    required Iterable<OneBestActionCandidate> candidates,
    required OneBestActionPolicy policy,
  }) {
    policy.validate();
    final context = contextResult.acceptedContext;
    final forecast = forecastResult.acceptedForecast;
    if (context == null || forecast == null) {
      return _finalize(
        status: OneBestActionStatus.rejected,
        asOf: contextResult.context.asOf,
        selected: null,
        ranked: const <RankedActionCandidate>[],
        reasons: const <String>[
          'accepted AI Context and metabolic forecast are required',
        ],
      );
    }

    final eligible =
        candidates
            .where(
              (candidate) =>
                  candidate.safetyEligible &&
                  candidate.evidenceIds.isNotEmpty &&
                  candidate.confidence >= policy.minimumConfidence &&
                  candidate.rankingScore >= policy.minimumScore,
            )
            .toList(growable: false)
          ..sort((left, right) {
            final score = right.rankingScore.compareTo(left.rankingScore);
            if (score != 0) {
              return score;
            }
            final confidence = right.confidence.compareTo(left.confidence);
            if (confidence != 0) {
              return confidence;
            }
            return left.id.compareTo(right.id);
          });

    if (eligible.isEmpty) {
      return _finalize(
        status: OneBestActionStatus.abstained,
        asOf: forecast.asOf,
        selected: null,
        ranked: const <RankedActionCandidate>[],
        reasons: const <String>[
          'no candidate satisfied evidence, confidence, score, and safety boundaries',
        ],
      );
    }

    final bounded = eligible.take(policy.maximumCandidates).toList();
    final ranked = <RankedActionCandidate>[
      for (var index = 0; index < bounded.length; index++)
        RankedActionCandidate(
          candidate: bounded[index],
          rank: index + 1,
          score: bounded[index].rankingScore,
        ),
    ];
    return _finalize(
      status: OneBestActionStatus.accepted,
      asOf: forecast.asOf,
      selected: bounded.first,
      ranked: ranked,
      reasons: <String>[
        'selected highest deterministic evidence-supported ranking score',
      ],
    );
  }

  OneBestActionResult _finalize({
    required OneBestActionStatus status,
    required DateTime asOf,
    required OneBestActionCandidate? selected,
    required Iterable<RankedActionCandidate> ranked,
    required Iterable<String> reasons,
  }) {
    final provisional = OneBestActionResult(
      status: status,
      asOf: asOf,
      selected: selected,
      rankedCandidates: ranked,
      reasons: reasons,
      integrityIssues: const <String>[],
    );
    return OneBestActionResult(
      status: status,
      asOf: asOf,
      selected: selected,
      rankedCandidates: ranked,
      reasons: reasons,
      integrityIssues: integrityValidator.validate(provisional),
    );
  }
}
