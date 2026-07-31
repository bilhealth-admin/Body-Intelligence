import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/explainable_ai_decision.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_conflict_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_gate_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_gate_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_report.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_trace.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gate = TruthDecisionGate();
  const validator = TruthDecisionValidator();
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

  test('accepts the established integrity-gated action decision', () {
    final result = gate.evaluate(
      report: _report(),
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(validator.validate(result).isValid, isTrue);
  });

  test('accepts the established uncertain abstention', () {
    final result = gate.evaluate(
      report: _report(
        status: TruthAssessmentStatus.uncertain,
        score: 0,
        confidence: 0.2,
        rationale: 'The deterministic evidence is balanced.',
      ),
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(validator.validate(result).isValid, isTrue);
  });

  test('reports every explainability mismatch without repairing output', () {
    final report = _report();
    final gateResult = TruthEvaluationGateResult.from(
      report: report,
      integrity: TruthIntegrityResult(issues: const []),
    );
    final forged = TruthDecisionGateResult<String>.accepted(
      gate: gateResult,
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

    final result = validator.validate(forged);

    expect(result.isValid, isFalse);
    expect(
      result.issues.map((issue) => issue.code),
      containsAll(<TruthDecisionIntegrityIssueCode>[
        TruthDecisionIntegrityIssueCode.dispositionMismatch,
        TruthDecisionIntegrityIssueCode.rationaleMismatch,
        TruthDecisionIntegrityIssueCode.evidenceMismatch,
        TruthDecisionIntegrityIssueCode.missingEvidenceMismatch,
      ]),
    );
  });

  test(
    'treats a rejected integrity gate as safe because no decision escaped',
    () {
      final report = _report();
      final rejectedGate = TruthEvaluationGateResult.from(
        report: report,
        integrity: TruthIntegrityResult(
          issues: [
            TruthIntegrityIssue(
              code: TruthIntegrityIssueCode.assessmentDirectionMismatch,
              message: 'Intentional test issue.',
              subjectKey: 'proposition.test',
            ),
          ],
        ),
      );
      final result = TruthDecisionGateResult<String>.rejected(
        gate: rejectedGate,
      );

      expect(validator.validate(result).isValid, isTrue);
    },
  );
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
