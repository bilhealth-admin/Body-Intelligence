import '../../../engine/one_best_action_engine.dart';

/// Explicit final states at the Dashboard recommendation-release boundary.
enum DashboardDecisionReleaseStatus {
  released,
  noRecommendation,
  insufficientEvidence,
  safetyBlocked,
  scientificallyUnsupported,
}

final class DashboardDecisionReleaseResult {
  const DashboardDecisionReleaseResult({
    required this.status,
    required this.exposedAction,
    required this.reasons,
  });

  final DashboardDecisionReleaseStatus status;
  final BestAction exposedAction;
  final List<String> reasons;

  bool get canRecommend => status == DashboardDecisionReleaseStatus.released;
}

/// Final deterministic boundary between a Truth-gated candidate and the UI.
///
/// This boundary does not diagnose or add medical meaning. It preserves
/// legitimate non-recommendation results, requires explicit local evidence,
/// blocks medical claims, and rejects action shapes outside the reviewed
/// Dashboard policy.
final class DashboardDecisionReleaseBoundary {
  const DashboardDecisionReleaseBoundary();

  static const _reviewedRecommendationTypes = <BestActionType>{
    BestActionType.weighIn,
    BestActionType.completeLogging,
    BestActionType.protein,
    BestActionType.hydration,
    BestActionType.holdPlan,
  };

  static const _blockedMedicalTerms = <String>{
    'diagnose',
    'diagnosis',
    'cure',
    'treat disease',
    'medical emergency',
    'stop medication',
    'change medication',
  };

  DashboardDecisionReleaseResult evaluate(BestAction candidate) {
    if (candidate.type == BestActionType.none) {
      return DashboardDecisionReleaseResult(
        status: DashboardDecisionReleaseStatus.noRecommendation,
        exposedAction: candidate,
        reasons: const <String>[
          'The deterministic authority intentionally selected no action.',
        ],
      );
    }

    final evidence = candidate.evidence
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (evidence.isEmpty) {
      return const DashboardDecisionReleaseResult(
        status: DashboardDecisionReleaseStatus.insufficientEvidence,
        exposedAction: insufficientEvidenceAction,
        reasons: <String>[
          'A recommendation cannot be released without explicit local evidence.',
        ],
      );
    }

    final language = '${candidate.title} ${candidate.reason}'.toLowerCase();
    final blockedTerms =
        _blockedMedicalTerms.where(language.contains).toList(growable: false)
          ..sort();
    if (blockedTerms.isNotEmpty) {
      return DashboardDecisionReleaseResult(
        status: DashboardDecisionReleaseStatus.safetyBlocked,
        exposedAction: safetyBlockedAction,
        reasons: <String>[
          'Unsupported medical language was blocked.',
          ...blockedTerms.map((term) => 'Blocked term: $term'),
        ],
      );
    }

    if (!_reviewedRecommendationTypes.contains(candidate.type) ||
        candidate.title.trim().isEmpty ||
        candidate.reason.trim().isEmpty ||
        candidate.title.length > 160 ||
        candidate.reason.length > 600) {
      return const DashboardDecisionReleaseResult(
        status: DashboardDecisionReleaseStatus.scientificallyUnsupported,
        exposedAction: scientificallyUnsupportedAction,
        reasons: <String>[
          'The candidate is outside the reviewed Dashboard action contract.',
        ],
      );
    }

    return DashboardDecisionReleaseResult(
      status: DashboardDecisionReleaseStatus.released,
      exposedAction: candidate,
      reasons: const <String>[
        'The action passed evidence, safety, and bounded-claim checks.',
      ],
    );
  }

  static const insufficientEvidenceAction = BestAction(
    type: BestActionType.none,
    title: 'More evidence is needed',
    reason:
        'BIL withheld the recommendation because no explicit supporting '
        'evidence was available.',
    evidence: <String>['Recommendation release boundary abstained'],
  );

  static const safetyBlockedAction = BestAction(
    type: BestActionType.none,
    title: 'No safe action is available',
    reason:
        'BIL withheld the recommendation because it crossed the bounded '
        'health-safety policy.',
    evidence: <String>['Recommendation release boundary blocked the action'],
  );

  static const scientificallyUnsupportedAction = BestAction(
    type: BestActionType.none,
    title: 'No supported action is available',
    reason:
        'BIL withheld the recommendation because the candidate was outside '
        'the reviewed scientific action contract.',
    evidence: <String>['Recommendation release boundary abstained'],
  );
}
