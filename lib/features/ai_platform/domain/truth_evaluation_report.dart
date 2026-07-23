import 'truth_assessment.dart';
import 'truth_conflict_analysis.dart';
import 'truth_evaluation_trace.dart';

/// Immutable explainability bundle for one deterministic proposition evaluation.
///
/// The report joins rule provenance, the existing Truth Engine assessment, and
/// conflict analysis without introducing recommendation policy, persistence,
/// provider access, clock access, randomness, or state mutation.
final class TruthEvaluationReport {
  const TruthEvaluationReport({required this.trace, required this.conflict});

  final TruthEvaluationTrace trace;
  final TruthConflictAnalysis conflict;

  TruthAssessment get assessment => trace.assessment;

  bool get abstains =>
      assessment.status == TruthAssessmentStatus.uncertain ||
      assessment.status == TruthAssessmentStatus.insufficientEvidence;
}
