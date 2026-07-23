import '../domain/ai_evidence.dart';
import '../domain/explainable_ai_decision.dart';
import '../domain/truth_assessment.dart';
import '../domain/truth_decision_gate_result.dart';
import '../domain/truth_decision_integrity_result.dart';

/// Pure local validator for the explainable decision emitted by the
/// integrity-gated Truth pipeline.
///
/// The validator performs no inference and never repairs or replaces a
/// decision. It reports deterministic integrity issues so downstream
/// components can refuse inconsistent output explicitly.
final class TruthDecisionValidator {
  const TruthDecisionValidator();

  TruthDecisionIntegrityResult validate<T>(TruthDecisionGateResult<T> result) {
    if (result.isRejected) {
      return TruthDecisionIntegrityResult(issues: const []);
    }

    final assessment = result.gate.report.assessment;
    final decision = result.decision!;
    final issues = <TruthDecisionIntegrityIssue>[];

    final shouldAct =
        assessment.status == TruthAssessmentStatus.supported ||
        assessment.status == TruthAssessmentStatus.contradicted;
    if (decision.hasAction != shouldAct) {
      issues.add(
        TruthDecisionIntegrityIssue(
          code: TruthDecisionIntegrityIssueCode.dispositionMismatch,
          message:
              'Decision disposition does not match the deterministic truth status.',
        ),
      );
    }

    if (decision.rationale != assessment.rationale) {
      issues.add(
        TruthDecisionIntegrityIssue(
          code: TruthDecisionIntegrityIssueCode.rationaleMismatch,
          message:
              'Decision rationale does not preserve the truth assessment rationale.',
        ),
      );
    }

    if (!_sameEvidence(decision.evidence, assessment.evidence)) {
      issues.add(
        TruthDecisionIntegrityIssue(
          code: TruthDecisionIntegrityIssueCode.evidenceMismatch,
          message:
              'Decision evidence does not exactly preserve truth assessment evidence.',
        ),
      );
    }

    final expectedConfidence = shouldAct
        ? _confidenceLevel(assessment.confidence)
        : AiConfidenceLevel.low;
    if (decision.confidence != expectedConfidence) {
      issues.add(
        TruthDecisionIntegrityIssue(
          code: TruthDecisionIntegrityIssueCode.confidenceMismatch,
          message:
              'Decision confidence does not match the deterministic confidence mapping.',
        ),
      );
    }

    final expectedMissingEvidence = switch (assessment.status) {
      TruthAssessmentStatus.uncertain => const [
        'resolved deterministic truth assessment',
      ],
      TruthAssessmentStatus.insufficientEvidence => assessment.missingEvidence,
      TruthAssessmentStatus.supported ||
      TruthAssessmentStatus.contradicted => assessment.missingEvidence,
    };
    if (!_sameStrings(decision.missingEvidence, expectedMissingEvidence)) {
      issues.add(
        TruthDecisionIntegrityIssue(
          code: TruthDecisionIntegrityIssueCode.missingEvidenceMismatch,
          message:
              'Decision missing-evidence disclosure does not match the truth status.',
        ),
      );
    }

    return TruthDecisionIntegrityResult(issues: issues);
  }

  bool _sameEvidence(List<AiEvidence> left, List<AiEvidence> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.key != b.key ||
          a.description != b.description ||
          a.source != b.source ||
          a.value != b.value) {
        return false;
      }
    }
    return true;
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  AiConfidenceLevel _confidenceLevel(double confidence) {
    if (confidence >= 0.75) {
      return AiConfidenceLevel.high;
    }
    if (confidence >= 0.5) {
      return AiConfidenceLevel.medium;
    }
    return AiConfidenceLevel.low;
  }
}
