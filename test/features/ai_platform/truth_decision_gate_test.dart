import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_conflict_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_gate_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_report.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_trace.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = TruthDecisionGate();
  final supported = TruthDecisionCandidate<String>(
    value: 'supported-action',
    label: 'Supported action',
    summary: 'Use the supported action.',
    reasonWhenNotChosen: 'The proposition was not supported.',
  );
  final contradicted = TruthDecisionCandidate<String>(
    value: 'contradicted-action',
    label: 'Contradicted action',
    summary: 'Use the contradicted action.',
    reasonWhenNotChosen: 'The proposition was not contradicted.',
  );

  test('produces a decision only after an accepted integrity gate', () {
    final result = service.evaluate(
      report: _validReport(),
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(result.status, TruthDecisionGateStatus.decisionAvailable);
    expect(result.canProceed, isTrue);
    expect(result.gate.canProceed, isTrue);
    expect(result.decision, isNotNull);
    expect(result.decision!.value, 'supported-action');
  });

  test('rejects an invalid report without invoking decision semantics', () {
    final valid = _validReport();
    final invalid = TruthEvaluationReport(
      trace: valid.trace,
      conflict: TruthConflictAnalysis(
        status: TruthConflictStatus.none,
        supportingSignalKeys: const ['unexpected.rule'],
        opposingSignalKeys: const [],
        supportWeight: 1,
        oppositionWeight: 0,
        margin: 1,
        rationale:
            'The supplied conflict fixture is intentionally inconsistent.',
      ),
    );

    final result = service.evaluate(
      report: invalid,
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(result.status, TruthDecisionGateStatus.rejected);
    expect(result.isRejected, isTrue);
    expect(result.gate.integrity.issues, isNotEmpty);
    expect(result.decision, isNull);
  });

  test('preserves established abstention for a valid uncertain report', () {
    final report = _validReport(
      status: TruthAssessmentStatus.uncertain,
      score: 0,
      confidence: 0.2,
      rationale: 'The deterministic evidence is balanced.',
    );

    final result = service.evaluate(
      report: report,
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(result.canProceed, isTrue);
    expect(result.decision!.hasAction, isFalse);
    expect(result.decision!.missingEvidence, isNotEmpty);
  });
}

TruthEvaluationReport _validReport({
  TruthAssessmentStatus status = TruthAssessmentStatus.supported,
  double score = 1,
  double confidence = 1,
  String rationale = 'Supporting evidence is decisive.',
}) {
  final assessment = TruthAssessment(
    status: status,
    score: score,
    confidence: confidence,
    rationale: rationale,
    evidence: [
      AiEvidence(
        key: 'support.evidence',
        source: 'truth_rule_composer',
        description: 'A deterministic observation.',
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
      rationale: 'Only supporting evidence matched.',
    ),
  );
}
