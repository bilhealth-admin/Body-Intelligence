import '../domain/truth_assessment.dart';
import '../domain/truth_conflict_analysis.dart';
import '../domain/truth_evaluation_report.dart';
import '../domain/truth_integrity_result.dart';

/// Pure local validator for the internal consistency of truth reports.
///
/// Validation adds no inference, thresholds, provider access, clock access,
/// randomness, persistence, recommendation ranking, or state mutation.
final class TruthEvaluationValidator {
  const TruthEvaluationValidator({this.numericTolerance = 0.000000001})
    : assert(numericTolerance >= 0);

  final double numericTolerance;

  TruthIntegrityResult validate(TruthEvaluationReport report) {
    final issues = <TruthIntegrityIssue>[];
    final matched = report.trace.matchedRuleKeys.toSet();
    final conflictKeys = <String>{
      ...report.conflict.supportingSignalKeys,
      ...report.conflict.opposingSignalKeys,
    };

    for (final key in conflictKeys.difference(matched)) {
      issues.add(
        TruthIntegrityIssue(
          code: TruthIntegrityIssueCode.conflictSignalNotMatched,
          subjectKey: key,
          message: 'Conflict signal $key is not present in matched rules.',
        ),
      );
    }
    for (final key in matched.difference(conflictKeys)) {
      issues.add(
        TruthIntegrityIssue(
          code: TruthIntegrityIssueCode.matchedRuleMissingFromConflict,
          subjectKey: key,
          message: 'Matched rule $key is missing from conflict analysis.',
        ),
      );
    }

    final expectedMargin =
        (report.conflict.supportWeight - report.conflict.oppositionWeight)
            .abs();
    if ((expectedMargin - report.conflict.margin).abs() > numericTolerance) {
      issues.add(
        TruthIntegrityIssue(
          code: TruthIntegrityIssueCode.conflictMarginMismatch,
          subjectKey: report.trace.propositionKey,
          message: 'Conflict margin does not equal the absolute weight delta.',
        ),
      );
    }

    if (!_statusMatches(report.conflict)) {
      issues.add(
        TruthIntegrityIssue(
          code: TruthIntegrityIssueCode.conflictStatusMismatch,
          subjectKey: report.trace.propositionKey,
          message: 'Conflict status is inconsistent with its signal groups.',
        ),
      );
    }

    if (!_assessmentDirectionMatches(report.assessment)) {
      issues.add(
        TruthIntegrityIssue(
          code: TruthIntegrityIssueCode.assessmentDirectionMismatch,
          subjectKey: report.trace.propositionKey,
          message: 'Assessment status is inconsistent with its signed score.',
        ),
      );
    }

    if (report.assessment.evidence.length != matched.length) {
      issues.add(
        TruthIntegrityIssue(
          code: TruthIntegrityIssueCode.evidenceCountMismatch,
          subjectKey: report.trace.propositionKey,
          message: 'Assessment evidence count does not match matched rules.',
        ),
      );
    }

    issues.sort((left, right) {
      final codeOrder = left.code.name.compareTo(right.code.name);
      return codeOrder != 0
          ? codeOrder
          : left.subjectKey.compareTo(right.subjectKey);
    });
    return TruthIntegrityResult(issues: issues);
  }

  bool _statusMatches(TruthConflictAnalysis conflict) {
    return switch (conflict.status) {
      TruthConflictStatus.none => !conflict.hasConflict,
      TruthConflictStatus.supportDominant =>
        conflict.hasConflict &&
            conflict.supportWeight > conflict.oppositionWeight,
      TruthConflictStatus.oppositionDominant =>
        conflict.hasConflict &&
            conflict.oppositionWeight > conflict.supportWeight,
      TruthConflictStatus.balanced => conflict.hasConflict,
    };
  }

  bool _assessmentDirectionMatches(TruthAssessment assessment) {
    return switch (assessment.status) {
      TruthAssessmentStatus.supported => assessment.score > 0,
      TruthAssessmentStatus.contradicted => assessment.score < 0,
      TruthAssessmentStatus.uncertain ||
      TruthAssessmentStatus.insufficientEvidence => true,
    };
  }
}
