import 'dart:io';

import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('existing assess API remains equivalent to trace assessment', () {
    final proposition = TruthProposition<int>(
      key: 'value.positive',
      description: 'The value is positive.',
    );
    final rules = [
      TruthRule<int>(
        key: 'positive',
        propositionKey: proposition.key,
        direction: TruthSignalDirection.supports,
        strength: 1,
        reliability: 1,
        matches: (value) => value > 0,
        evidence: (value) => AiEvidence(
          key: 'value',
          description: 'Local integer value.',
          source: 'test',
          value: value,
        ),
      ),
    ];
    const composer = TruthRuleComposer();

    final assessment = composer.assess(
      proposition: proposition,
      context: 2,
      rules: rules,
    );
    final traced = composer.trace(
      proposition: proposition,
      context: 2,
      rules: rules,
    );

    expect(traced.assessment.status, assessment.status);
    expect(traced.assessment.score, assessment.score);
    expect(traced.assessment.confidence, assessment.confidence);
    expect(traced.assessment.rationale, assessment.rationale);
  });

  test('truth trace remains provider-neutral and offline-only', () {
    const files = [
      'lib/features/ai_platform/domain/truth_evaluation_trace.dart',
      'lib/features/ai_platform/services/truth_rule_composer.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('dart:io')));
      expect(source, isNot(contains('http')));
      expect(source, isNot(contains('Firebase')));
      expect(source, isNot(contains('DateTime.now')));
      expect(source, isNot(contains('Random(')));
    }
  });
}
