import 'truth_evaluation_report.dart';
import 'truth_integrity_result.dart';

/// Stable outcome of integrity-gating one deterministic truth evaluation.
enum TruthEvaluationGateStatus { accepted, rejected }

/// Immutable gate result that preserves both the report and validation evidence.
///
/// The status is derived exclusively from [integrity]. Consumers can inspect a
/// rejected report for diagnostics, but [canProceed] is true only when the
/// integrity validator found no issues.
final class TruthEvaluationGateResult {
  TruthEvaluationGateResult._({
    required this.report,
    required this.integrity,
    required this.status,
  });

  factory TruthEvaluationGateResult.from({
    required TruthEvaluationReport report,
    required TruthIntegrityResult integrity,
  }) {
    return TruthEvaluationGateResult._(
      report: report,
      integrity: integrity,
      status: integrity.isValid
          ? TruthEvaluationGateStatus.accepted
          : TruthEvaluationGateStatus.rejected,
    );
  }

  final TruthEvaluationReport report;
  final TruthIntegrityResult integrity;
  final TruthEvaluationGateStatus status;

  bool get canProceed => status == TruthEvaluationGateStatus.accepted;
  bool get isRejected => status == TruthEvaluationGateStatus.rejected;
}
