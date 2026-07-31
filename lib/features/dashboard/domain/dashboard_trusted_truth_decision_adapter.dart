import '../../../engine/one_best_action_engine.dart';
import '../../ai_platform/domain/ai_evidence.dart';
import '../../ai_platform/domain/truth_decision_candidate.dart';
import '../../ai_platform/domain/truth_proposition.dart';
import '../../ai_platform/domain/truth_rule.dart';
import '../../ai_platform/domain/truth_signal.dart';
import '../../ai_platform/domain/trusted_truth_decision_result.dart';
import '../../ai_platform/services/trusted_truth_decision_pipeline.dart';

final class DashboardTruthDecisionContext {
  const DashboardTruthDecisionContext({
    required this.weighedToday,
    required this.loggingComplete,
    required this.protein,
    required this.proteinTarget,
    required this.waterMl,
    required this.waterTarget,
    required this.trackedDays,
    required this.proposedAction,
  });

  final bool weighedToday;
  final bool loggingComplete;
  final double protein;
  final int proteinTarget;
  final int waterMl;
  final int waterTarget;
  final int trackedDays;
  final BestAction proposedAction;

  bool get hasValidDeterministicInputs =>
      DashboardTrustedTruthDecisionAdapter.inputsAreValid(
        protein: protein,
        proteinTarget: proteinTarget,
        waterMl: waterMl,
        waterTarget: waterTarget,
        trackedDays: trackedDays,
      );
}

final class DashboardTrustedTruthDecision {
  const DashboardTrustedTruthDecision({
    required this.result,
    required this.engineVersion,
    required this.inputEvidenceKeys,
  });

  final TrustedTruthDecisionResult<BestAction> result;
  final String engineVersion;
  final List<String> inputEvidenceKeys;

  BestAction? get action => result.decision;
  bool get isSafeAbstention => result.isSafeAbstention;
}

/// Adapts the deterministic Dashboard action into the trusted Truth/Explain
/// pipeline without re-ranking, mutating, localizing, or persisting it.
final class DashboardTrustedTruthDecisionAdapter {
  const DashboardTrustedTruthDecisionAdapter({
    this.pipeline = const TrustedTruthDecisionPipeline(),
  });

  static bool inputsAreValid({
    required double protein,
    required int proteinTarget,
    required int waterMl,
    required int waterTarget,
    required int trackedDays,
  }) =>
      protein.isFinite &&
      protein >= 0 &&
      proteinTarget > 0 &&
      waterMl >= 0 &&
      waterTarget > 0 &&
      trackedDays >= 0;

  static const engineVersion = 'dashboard-truth-adapter-v1';
  static const _propositionKey = 'dashboard.action.inputs_are_valid';
  static const inputEvidenceKeys = <String>[
    'protein',
    'proteinTarget',
    'waterMl',
    'waterTarget',
    'trackedDays',
  ];

  final TrustedTruthDecisionPipeline pipeline;

  DashboardTrustedTruthDecision evaluate(
    DashboardTruthDecisionContext context,
  ) {
    final proposed = context.proposedAction;
    final result = pipeline.evaluate<DashboardTruthDecisionContext, BestAction>(
      proposition: TruthProposition<DashboardTruthDecisionContext>(
        key: _propositionKey,
        description:
            'The proposed Dashboard action is based on structurally valid '
            'deterministic inputs.',
      ),
      context: context,
      rules: [
        TruthRule<DashboardTruthDecisionContext>(
          key: 'dashboard.action.valid_deterministic_inputs',
          propositionKey: _propositionKey,
          direction: TruthSignalDirection.supports,
          strength: 1,
          reliability: 1,
          matches: (value) => value.hasValidDeterministicInputs,
          evidence: (value) => AiEvidence(
            key: 'dashboard.action.input_validation',
            description: 'Dashboard decision inputs passed local validation.',
            source: engineVersion,
            value: <String, Object>{
              'protein': value.protein,
              'proteinTarget': value.proteinTarget,
              'waterMl': value.waterMl,
              'waterTarget': value.waterTarget,
              'trackedDays': value.trackedDays,
              'proposedActionType': value.proposedAction.type.name,
            },
          ),
        ),
      ],
      supportedCandidate: TruthDecisionCandidate<BestAction>(
        value: proposed,
        label: proposed.title,
        summary: 'The deterministic Dashboard action passed the Truth gate.',
        reasonWhenNotChosen:
            'The deterministic inputs did not pass the trusted Truth gate.',
      ),
      contradictedCandidate: TruthDecisionCandidate<BestAction>(
        value: abstentionAction,
        label: abstentionAction.title,
        summary: 'The Dashboard cannot expose an action from invalid inputs.',
        reasonWhenNotChosen:
            'The deterministic inputs passed the trusted Truth gate.',
      ),
    );

    return DashboardTrustedTruthDecision(
      result: result,
      engineVersion: engineVersion,
      inputEvidenceKeys: inputEvidenceKeys,
    );
  }

  static const abstentionAction = BestAction(
    type: BestActionType.none,
    title: 'No trusted action is available yet',
    reason:
        'BIL withheld the recommendation because its deterministic inputs '
        'were incomplete or invalid.',
    evidence: ['Trusted Truth gate did not expose a recommendation'],
  );
}
