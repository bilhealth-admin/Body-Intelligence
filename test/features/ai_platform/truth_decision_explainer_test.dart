import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/explainable_ai_decision.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_explainer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const explainer = TruthDecisionExplainer();
  final supported = TruthDecisionCandidate<String>(
    value: 'supported_path',
    label: 'Use supported path',
    summary: 'Use the supported deterministic path.',
    reasonWhenNotChosen: 'The proposition was not supported.',
  );
  final contradicted = TruthDecisionCandidate<String>(
    value: 'contradicted_path',
    label: 'Use contradicted path',
    summary: 'Use the contradicted deterministic path.',
    reasonWhenNotChosen: 'The proposition was not contradicted.',
  );
  final evidence = AiEvidence(
    key: 'local.signal',
    description: 'Locally computed deterministic signal.',
    source: 'TruthEngine',
    value: 1,
  );

  test('selects the supported candidate and preserves evidence', () {
    final decision = explainer.explain(
      assessment: TruthAssessment(
        status: TruthAssessmentStatus.supported,
        score: 0.8,
        confidence: 0.9,
        rationale: 'The deterministic evidence supports the proposition.',
        evidence: [evidence],
        missingEvidence: const [],
      ),
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(decision.disposition, AiDecisionDisposition.action);
    expect(decision.value, 'supported_path');
    expect(decision.confidence, AiConfidenceLevel.high);
    expect(decision.evidence.single.key, 'local.signal');
    expect(decision.alternatives.single.label, 'Use contradicted path');
  });

  test('selects the contradicted candidate deterministically', () {
    final decision = explainer.explain(
      assessment: TruthAssessment(
        status: TruthAssessmentStatus.contradicted,
        score: -0.7,
        confidence: 0.6,
        rationale: 'The deterministic evidence contradicts the proposition.',
        evidence: [evidence],
        missingEvidence: const [],
      ),
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(decision.value, 'contradicted_path');
    expect(decision.confidence, AiConfidenceLevel.medium);
    expect(decision.alternatives.single.label, 'Use supported path');
  });

  test('abstains for uncertain truth without inventing a value', () {
    final decision = explainer.explain(
      assessment: TruthAssessment(
        status: TruthAssessmentStatus.uncertain,
        score: 0.1,
        confidence: 0.8,
        rationale: 'Signals do not resolve the proposition.',
        evidence: [evidence],
        missingEvidence: const [],
      ),
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(decision.disposition, AiDecisionDisposition.abstain);
    expect(decision.value, isNull);
    expect(decision.missingEvidence, [
      'resolved deterministic truth assessment',
    ]);
    expect(decision.alternatives, hasLength(2));
  });

  test('preserves explicit missing evidence when evidence is insufficient', () {
    final decision = explainer.explain(
      assessment: TruthAssessment(
        status: TruthAssessmentStatus.insufficientEvidence,
        score: 0,
        confidence: 0,
        rationale: 'Required evidence is missing.',
        evidence: const [],
        missingEvidence: const ['today.weight', 'today.intake'],
      ),
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(decision.hasAction, isFalse);
    expect(decision.missingEvidence, ['today.weight', 'today.intake']);
    expect(decision.confidence, AiConfidenceLevel.low);
  });

  test('candidate text is normalized and validated', () {
    final candidate = TruthDecisionCandidate<int>(
      value: 1,
      label: '  Candidate  ',
      summary: '  Summary  ',
      reasonWhenNotChosen: '  Reason  ',
    );

    expect(candidate.label, 'Candidate');
    expect(candidate.summary, 'Summary');
    expect(candidate.reasonWhenNotChosen, 'Reason');
    expect(
      () => TruthDecisionCandidate<int>(
        value: 1,
        label: ' ',
        summary: 'Summary',
        reasonWhenNotChosen: 'Reason',
      ),
      throwsArgumentError,
    );
  });
}
