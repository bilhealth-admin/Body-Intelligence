import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_evaluation_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gate accepts the unchanged report emitted by TruthRuleComposer', () {
    const composer = TruthRuleComposer();
    const gate = TruthEvaluationGate();
    final proposition = TruthProposition<bool>(
      key: 'proposition.enabled',
      description: 'Whether the local feature is enabled.',
    );
    final rules = [
      TruthRule<bool>(
        key: 'enabled.rule',
        propositionKey: proposition.key,
        direction: TruthSignalDirection.supports,
        strength: 1,
        matches: (value) => value,
        reliability: 1,
        evidence: (_) => AiEvidence(
          key: 'enabled.evidence',
          source: 'truth_rule_composer',
          description: 'The feature is enabled.',
        ),
      ),
    ];

    final report = composer.report(
      proposition: proposition,
      context: true,
      rules: rules,
    );
    final result = gate.evaluate(report);

    expect(result.canProceed, isTrue);
    expect(result.report.assessment, same(report.assessment));
    expect(result.report.trace, same(report.trace));
    expect(result.report.conflict, same(report.conflict));
  });
}
