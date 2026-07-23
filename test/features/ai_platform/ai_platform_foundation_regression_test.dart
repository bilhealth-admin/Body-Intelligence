import 'dart:io';

import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/explainable_ai_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI foundation remains offline and provider neutral', () {
    final files = [
      File('lib/features/ai_platform/domain/ai_evidence.dart'),
      File('lib/features/ai_platform/domain/explainable_ai_decision.dart'),
    ];

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('package:http/')));
      expect(source, isNot(contains('dart:io')));
      expect(source, isNot(contains('firebase')));
      expect(source, isNot(contains('openai')));
      expect(source, isNot(contains('features/commerce')));
    }
  });

  test('the contract supports safe non-recommendation behavior', () {
    final decision = ExplainableAiDecision<String>.abstain(
      summary: 'No recommendation.',
      rationale: 'BIL does not have enough current evidence.',
      evidence: [
        AiEvidence(
          key: 'history_count',
          description: 'Available local history count',
          source: 'LocalRepository',
          value: 0,
        ),
      ],
      missingEvidence: const ['current_weight'],
    );

    expect(decision.disposition, AiDecisionDisposition.abstain);
    expect(decision.value, isNull);
  });
}
