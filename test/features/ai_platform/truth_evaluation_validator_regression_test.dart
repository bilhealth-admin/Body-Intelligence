import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_evaluation_validator.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('integrity validation does not change composer report semantics', () {
    final proposition = TruthProposition<int>(
      key: 'weight.trend.available',
      description: 'Weight trend evidence is available.',
      requiredEvidenceKeys: const ['weight.samples'],
    );
    final rules = [
      TruthRule<int>(
        key: 'weight.samples.rule',
        propositionKey: proposition.key,
        direction: TruthSignalDirection.supports,
        strength: 0.9,
        reliability: 0.8,
        matches: (samples) => samples >= 3,
        evidence: (samples) => AiEvidence(
          key: 'weight.samples',
          description: '$samples weight samples are available.',
          source: 'body_log',
          value: samples,
        ),
      ),
    ];
    const composer = TruthRuleComposer();

    final report = composer.report<int>(
      proposition: proposition,
      context: 4,
      rules: rules,
    );
    final assessment = composer.assess<int>(
      proposition: proposition,
      context: 4,
      rules: rules,
    );
    final trace = composer.trace<int>(
      proposition: proposition,
      context: 4,
      rules: rules,
    );

    expect(const TruthEvaluationValidator().validate(report).isValid, isTrue);
    expect(report.assessment.status, assessment.status);
    expect(report.assessment.score, assessment.score);
    expect(report.trace.matchedRuleKeys, trace.matchedRuleKeys);
  });
}
