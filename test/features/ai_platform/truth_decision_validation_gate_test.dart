import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/explainable_ai_decision.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_conflict_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_gate_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_validation_gate_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_gate_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_report.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_trace.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_validation_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const decisionGate = TruthDecisionGate();
  const validationGate = TruthDecisionValidationGate();
  final supported = TruthDecisionCandidate<String>(
    value: 'supported-action',
    label: 'Supported action',
    summary: 'Use the supported action.',
    reasonWhenNotChosen: 'Support was not established.',
  );
  final contradicted = TruthDecisionCandidate<String>(
    value: 'contradicted-action',
    label: 'Contradicted action',
    summary: 'Use the contradicted action.',
    reasonWhenNotChosen: 'Contradiction was not established.',
  );

  test('exposes an integrity-valid action decision', () {
    final decision = decisionGate.evaluate(
      report: _report(),
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    final result = validationGate.evaluate(decision);

    expect(result.status, TruthDecisionValidationGateStatus.accepted);
    expect(result.canExposeDecision, isTrue);
    expect(result.isSafeUpstreamRejection, isFalse);
    expect(result.integrity.issues, isEmpty);
    expect(identical(result.decisionResult, decision), isTrue);
  });

  test('exposes an integrity-valid explainable abstention', () {
    final decision = decisionGate.evaluate(
      report: _report(
        status: TruthAssessmentStatus.uncertain,
        score: 0,
        confidence: 0.2,
        rationale: 'The deterministic evidence is balanced.',
      ),
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    final result = validationGate.evaluate(decision);

    expect(result.isIntegrityAccepted, isTrue);
    expect(result.canExposeDecision, isTrue);
    expect(result.decisionResult.decision!.hasAction, isFalse);
  });

  test('preserves a safe upstream rejection without exposing a decision', () {
    final report = _report();
    final rejectedGate = TruthEvaluationGateResult.from(
      report: report,
      integrity: TruthIntegrityResult(
        issues: [
          TruthIntegrityIssue(
            code: TruthIntegrityIssueCode.assessmentDirectionMismatch,
            message: 'Intentional invalid report.',
            subjectKey: 'proposition.test',
          ),
        ],
      ),
    );
    final decision = TruthDecisionGateResult<String>.rejected(
      gate: rejectedGate,
    );

    final result = validationGate.evaluate(decision);

    expect(result.isIntegrityAccepted, isTrue);
    expect(result.isSafeUpstreamRejection, isTrue);
    expect(result.canExposeDecision, isFalse);
    expect(result.decisionResult.decision, isNull);
  });

  test('rejects a forged decision and preserves every fidelity issue', () {
    final report = _report();
    final acceptedGate = TruthEvaluationGateResult.from(
      report: report,
      integrity: TruthIntegrityResult(issues: const []),
    );
    final forged = TruthDecisionGateResult<String>.accepted(
      gate: acceptedGate,
      decision: ExplainableAiDecision<String>.abstain(
        summary: 'Forged decision.',
        rationale: 'Different rationale.',
        evidence: [
          AiEvidence(
            key: 'different.evidence',
            description: 'Not assessment evidence.',
            source: 'test',
          ),
        ],
        missingEvidence: const ['different missing evidence'],
      ),
    );

    final result = validationGate.evaluate(forged);

    expect(result.status, TruthDecisionValidationGateStatus.rejected);
    expect(result.canExposeDecision, isFalse);
    expect(result.isIntegrityRejected, isTrue);
    expect(
      result.integrity.issues.map((issue) => issue.code),
      containsAll(<TruthDecisionIntegrityIssueCode>[
        TruthDecisionIntegrityIssueCode.dispositionMismatch,
        TruthDecisionIntegrityIssueCode.rationaleMismatch,
        TruthDecisionIntegrityIssueCode.evidenceMismatch,
        TruthDecisionIntegrityIssueCode.missingEvidenceMismatch,
      ]),
    );
    expect(identical(result.decisionResult, forged), isTrue);
  });
}

TruthEvaluationReport _report({
  TruthAssessmentStatus status = TruthAssessmentStatus.supported,
  double score = 1,
  double confidence = 1,
  String rationale = 'Supporting evidence is decisive.',
}) {
  final evidence = AiEvidence(
    key: 'support.evidence',
    description: 'A deterministic observation.',
    source: 'truth_rule_composer',
  );
  return TruthEvaluationReport(
    trace: TruthEvaluationTrace(
      propositionKey: 'proposition.test',
      consideredRuleKeys: const ['support.rule'],
      matchedRuleKeys: const ['support.rule'],
      assessment: TruthAssessment(
        status: status,
        score: score,
        confidence: confidence,
        rationale: rationale,
        evidence: [evidence],
        missingEvidence: const [],
      ),
    ),
    conflict: TruthConflictAnalysis(
      status: TruthConflictStatus.none,
      supportingSignalKeys: const ['support.rule'],
      opposingSignalKeys: const [],
      supportWeight: 1,
      oppositionWeight: 0,
      margin: 1,
      rationale: 'Only supporting evidence matched.',
    ),
  );
}
