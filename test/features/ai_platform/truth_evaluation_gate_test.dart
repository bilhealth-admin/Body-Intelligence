import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_conflict_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_gate_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_report.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_trace.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_evaluation_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gate = TruthEvaluationGate();

  test('accepts a report with no integrity issues', () {
    final report = _validReport();

    final result = gate.evaluate(report);

    expect(result.status, TruthEvaluationGateStatus.accepted);
    expect(result.canProceed, isTrue);
    expect(result.isRejected, isFalse);
    expect(result.integrity.issues, isEmpty);
    expect(identical(result.report, report), isTrue);
  });

  test('rejects a report and preserves explainable issue evidence', () {
    final valid = _validReport();
    final malformed = TruthEvaluationReport(
      trace: valid.trace,
      conflict: TruthConflictAnalysis(
        status: TruthConflictStatus.none,
        supportingSignalKeys: const ['unexpected.rule'],
        opposingSignalKeys: const [],
        supportWeight: 1,
        oppositionWeight: 0,
        margin: 1,
        rationale: 'Malformed conflict fixture.',
      ),
    );

    final result = gate.evaluate(malformed);

    expect(result.status, TruthEvaluationGateStatus.rejected);
    expect(result.canProceed, isFalse);
    expect(result.isRejected, isTrue);
    expect(result.integrity.isValid, isFalse);
    expect(
      result.integrity.issues.map((issue) => issue.code),
      contains(TruthIntegrityIssueCode.conflictSignalNotMatched),
    );
    expect(identical(result.report, malformed), isTrue);
  });

  test('returns deterministic issue ordering for identical input', () {
    final valid = _validReport();
    final malformed = TruthEvaluationReport(
      trace: TruthEvaluationTrace(
        propositionKey: valid.trace.propositionKey,
        consideredRuleKeys: const ['support.rule', 'missing.rule'],
        matchedRuleKeys: const ['support.rule', 'missing.rule'],
        assessment: valid.assessment,
      ),
      conflict: valid.conflict,
    );

    final first = gate.evaluate(malformed);
    final second = gate.evaluate(malformed);

    expect(
      first.integrity.issues.map((issue) => issue.code).toList(),
      second.integrity.issues.map((issue) => issue.code).toList(),
    );
    expect(
      first.integrity.issues.map((issue) => issue.subjectKey).toList(),
      second.integrity.issues.map((issue) => issue.subjectKey).toList(),
    );
  });
}

TruthEvaluationReport _validReport() {
  final assessment = TruthAssessment(
    status: TruthAssessmentStatus.supported,
    score: 1,
    confidence: 1,
    rationale: 'Supporting evidence is decisive.',
    evidence: [
      AiEvidence(
        key: 'support.evidence',
        source: 'truth_rule_composer',
        description: 'A deterministic supporting observation.',
      ),
    ],
    missingEvidence: const [],
  );
  return TruthEvaluationReport(
    trace: TruthEvaluationTrace(
      propositionKey: 'proposition.test',
      consideredRuleKeys: const ['support.rule'],
      matchedRuleKeys: const ['support.rule'],
      assessment: assessment,
    ),
    conflict: TruthConflictAnalysis(
      status: TruthConflictStatus.none,
      supportingSignalKeys: const ['support.rule'],
      opposingSignalKeys: const [],
      supportWeight: 1,
      oppositionWeight: 0,
      margin: 1,
      rationale: 'Only supporting signals matched.',
    ),
  );
}
