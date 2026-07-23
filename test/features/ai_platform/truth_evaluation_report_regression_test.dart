import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const composer = TruthRuleComposer();

  test('existing assess and trace APIs preserve report semantics', () {
    final proposition = TruthProposition<int>(
      key: 'regression.proposition',
      description: 'Regression proposition.',
      requiredEvidenceKeys: const ['regression.evidence'],
    );
    final rules = [
      TruthRule<int>(
        key: 'regression.rule',
        propositionKey: proposition.key,
        direction: TruthSignalDirection.supports,
        matches: (value) => value > 0,
        evidence: (_) => AiEvidence(
          key: 'regression.evidence',
          description: 'Regression evidence.',
          source: 'truth_rule_composer',
        ),
        strength: 0.9,
        reliability: 1,
      ),
    ];

    final report = composer.report(
      proposition: proposition,
      context: 1,
      rules: rules,
    );
    final assessment = composer.assess(
      proposition: proposition,
      context: 1,
      rules: rules,
    );
    final trace = composer.trace(
      proposition: proposition,
      context: 1,
      rules: rules,
    );

    expect(assessment.status, report.assessment.status);
    expect(assessment.confidence, report.assessment.confidence);
    expect(assessment.rationale, report.assessment.rationale);
    expect(trace.propositionKey, report.trace.propositionKey);
    expect(trace.consideredRuleKeys, report.trace.consideredRuleKeys);
    expect(trace.matchedRuleKeys, report.trace.matchedRuleKeys);
  });
}
