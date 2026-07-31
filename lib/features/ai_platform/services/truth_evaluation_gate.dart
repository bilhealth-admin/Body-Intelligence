import '../domain/truth_evaluation_gate_result.dart';
import '../domain/truth_evaluation_report.dart';
import 'truth_evaluation_validator.dart';

/// Pure local boundary that integrity-gates deterministic truth reports.
///
/// This service adds no inference, recommendation policy, provider access,
/// clock access, randomness, persistence, or state mutation. It only converts
/// the existing validator result into an explicit proceed/reject contract.
final class TruthEvaluationGate {
  const TruthEvaluationGate({
    this.validator = const TruthEvaluationValidator(),
  });

  final TruthEvaluationValidator validator;

  TruthEvaluationGateResult evaluate(TruthEvaluationReport report) {
    return TruthEvaluationGateResult.from(
      report: report,
      integrity: validator.validate(report),
    );
  }
}
