import 'trusted_truth_decision_result.dart';

/// Stable public outcome exposed by the completed local Truth/Explain
/// foundation.
enum TruthExplainFoundationStatus { action, abstention, rejected }

/// Immutable consumer boundary over [TrustedTruthDecisionResult].
///
/// It classifies the already validated trusted result without performing new
/// inference, ranking, persistence, network access, or user-state mutation.
final class TruthExplainFoundationResult<T> {
  TruthExplainFoundationResult._({
    required this.trustedResult,
    required this.status,
  });

  factory TruthExplainFoundationResult.fromTrusted(
    TrustedTruthDecisionResult<T> trustedResult,
  ) {
    if (trustedResult.canExposeDecision) {
      return TruthExplainFoundationResult<T>._(
        trustedResult: trustedResult,
        status: TruthExplainFoundationStatus.action,
      );
    }
    if (trustedResult.isSafeAbstention) {
      return TruthExplainFoundationResult<T>._(
        trustedResult: trustedResult,
        status: TruthExplainFoundationStatus.abstention,
      );
    }
    if (trustedResult.isRejected || trustedResult.isSafeRejection) {
      return TruthExplainFoundationResult<T>._(
        trustedResult: trustedResult,
        status: TruthExplainFoundationStatus.rejected,
      );
    }
    throw StateError(
      'Trusted Truth/Explain result has no valid public outcome.',
    );
  }

  final TrustedTruthDecisionResult<T> trustedResult;
  final TruthExplainFoundationStatus status;

  bool get hasAction => status == TruthExplainFoundationStatus.action;
  bool get isAbstention => status == TruthExplainFoundationStatus.abstention;
  bool get isRejected => status == TruthExplainFoundationStatus.rejected;

  T? get decision => hasAction ? trustedResult.decision : null;
}
