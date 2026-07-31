import 'dart:io';

import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_explainer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('truth explanation boundary remains offline and provider neutral', () {
    final files = [
      File('lib/features/ai_platform/domain/truth_decision_candidate.dart'),
      File('lib/features/ai_platform/services/truth_decision_explainer.dart'),
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('package:http/')));
      expect(source, isNot(contains('dart:io')));
      expect(source, isNot(contains('firebase')));
      expect(source, isNot(contains('openai')));
      expect(source, isNot(contains('features/commerce')));
      expect(source, isNot(contains('features/nutrition')));
      expect(source, isNot(contains('DateTime')));
      expect(source, isNot(contains('Random')));
    }
  });

  test('same assessment and candidates produce the same decision', () {
    const explainer = TruthDecisionExplainer();
    final assessment = TruthAssessment(
      status: TruthAssessmentStatus.supported,
      score: 0.5,
      confidence: 0.75,
      rationale: 'Stable deterministic rationale.',
      evidence: [
        AiEvidence(
          key: 'stable',
          description: 'Stable evidence.',
          source: 'TruthEngine',
        ),
      ],
      missingEvidence: const [],
    );
    final supported = TruthDecisionCandidate<String>(
      value: 'yes',
      label: 'Yes',
      summary: 'Select yes.',
      reasonWhenNotChosen: 'Not supported.',
    );
    final contradicted = TruthDecisionCandidate<String>(
      value: 'no',
      label: 'No',
      summary: 'Select no.',
      reasonWhenNotChosen: 'Not contradicted.',
    );

    final first = explainer.explain(
      assessment: assessment,
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );
    final second = explainer.explain(
      assessment: assessment,
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(second.disposition, first.disposition);
    expect(second.value, first.value);
    expect(second.summary, first.summary);
    expect(second.rationale, first.rationale);
    expect(second.confidence, first.confidence);
    expect(
      second.evidence.map((item) => item.key),
      orderedEquals(first.evidence.map((item) => item.key)),
    );
  });
}
