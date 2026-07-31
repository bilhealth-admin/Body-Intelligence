import 'truth_decision_pipeline_integrity_result.dart';
import 'truth_decision_pipeline_result.dart';

/// Stable outcome of integrity-gating one trusted Truth/Explain pipeline result.
enum TruthDecisionPipelineIntegrityGateStatus { accepted, rejected }

/// Immutable consumption boundary over [TruthDecisionPipelineResult].
///
/// The original result remains inspectable for diagnostics. Downstream code may
/// consume it only when [canProceed] is true.
final class TruthDecisionPipelineIntegrityGateResult<T> {
  TruthDecisionPipelineIntegrityGateResult._({
    required this.pipelineResult,
    required this.integrity,
    required this.status,
  });

  factory TruthDecisionPipelineIntegrityGateResult.from({
    required TruthDecisionPipelineResult<T> pipelineResult,
    required TruthDecisionPipelineIntegrityResult integrity,
  }) {
    return TruthDecisionPipelineIntegrityGateResult<T>._(
      pipelineResult: pipelineResult,
      integrity: integrity,
      status: integrity.isValid
          ? TruthDecisionPipelineIntegrityGateStatus.accepted
          : TruthDecisionPipelineIntegrityGateStatus.rejected,
    );
  }

  final TruthDecisionPipelineResult<T> pipelineResult;
  final TruthDecisionPipelineIntegrityResult integrity;
  final TruthDecisionPipelineIntegrityGateStatus status;

  bool get canProceed =>
      status == TruthDecisionPipelineIntegrityGateStatus.accepted;

  bool get isRejected =>
      status == TruthDecisionPipelineIntegrityGateStatus.rejected;
}
