import '../domain/explainable_ai_decision.dart';
import '../domain/truth_assessment.dart';
import '../domain/truth_decision_candidate.dart';

/// Deterministic bridge from Truth Engine output to BIL's explainability
/// contract.
///
/// This service does not infer an action, call a provider, access a clock,
/// persist data, or mutate user state. The caller supplies the two candidate
/// values. The bridge selects one only for resolved supported/contradicted
/// assessments and safely abstains for uncertain or insufficient evidence.
final class TruthDecisionExplainer {
  const TruthDecisionExplainer();

  ExplainableAiDecision<T> explain<T>({
    required TruthAssessment assessment,
    required TruthDecisionCandidate<T> supportedCandidate,
    required TruthDecisionCandidate<T> contradictedCandidate,
  }) {
    return switch (assessment.status) {
      TruthAssessmentStatus.supported => _action(
        assessment: assessment,
        selected: supportedCandidate,
        alternative: contradictedCandidate,
      ),
      TruthAssessmentStatus.contradicted => _action(
        assessment: assessment,
        selected: contradictedCandidate,
        alternative: supportedCandidate,
      ),
      TruthAssessmentStatus.uncertain => _abstain(
        assessment: assessment,
        supportedCandidate: supportedCandidate,
        contradictedCandidate: contradictedCandidate,
        missingEvidence: const ['resolved deterministic truth assessment'],
      ),
      TruthAssessmentStatus.insufficientEvidence => _abstain(
        assessment: assessment,
        supportedCandidate: supportedCandidate,
        contradictedCandidate: contradictedCandidate,
        missingEvidence: assessment.missingEvidence,
      ),
    };
  }

  ExplainableAiDecision<T> _action<T>({
    required TruthAssessment assessment,
    required TruthDecisionCandidate<T> selected,
    required TruthDecisionCandidate<T> alternative,
  }) {
    return ExplainableAiDecision<T>.action(
      value: selected.value,
      summary: selected.summary,
      rationale: assessment.rationale,
      evidence: assessment.evidence,
      confidence: _confidenceLevel(assessment.confidence),
      alternatives: [
        AiDecisionAlternative(
          label: alternative.label,
          reasonNotChosen: alternative.reasonWhenNotChosen,
        ),
      ],
      missingEvidence: assessment.missingEvidence,
    );
  }

  ExplainableAiDecision<T> _abstain<T>({
    required TruthAssessment assessment,
    required TruthDecisionCandidate<T> supportedCandidate,
    required TruthDecisionCandidate<T> contradictedCandidate,
    required Iterable<String> missingEvidence,
  }) {
    return ExplainableAiDecision<T>.abstain(
      summary: 'No deterministic decision is available.',
      rationale: assessment.rationale,
      evidence: assessment.evidence,
      alternatives: [
        AiDecisionAlternative(
          label: supportedCandidate.label,
          reasonNotChosen: supportedCandidate.reasonWhenNotChosen,
        ),
        AiDecisionAlternative(
          label: contradictedCandidate.label,
          reasonNotChosen: contradictedCandidate.reasonWhenNotChosen,
        ),
      ],
      missingEvidence: missingEvidence,
    );
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
