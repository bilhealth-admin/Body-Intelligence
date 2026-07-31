import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_gate.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepted composer report retains existing decision selection', () {
    const composer = TruthRuleComposer();
    const service = TruthDecisionGate();
    final proposition = TruthProposition<bool>(
      key: 'proposition.enabled',
      description: 'Whether the deterministic feature flag is enabled.',
    );
    final report = composer.report(
      proposition: proposition,
      context: true,
      rules: [
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
      ],
    );
    final result = service.evaluate(
      report: report,
      supportedCandidate: TruthDecisionCandidate<String>(
        value: 'enabled',
        label: 'Enabled',
        summary: 'Keep the feature enabled.',
        reasonWhenNotChosen: 'The proposition was not supported.',
      ),
      contradictedCandidate: TruthDecisionCandidate<String>(
        value: 'disabled',
        label: 'Disabled',
        summary: 'Disable the feature.',
        reasonWhenNotChosen: 'The proposition was not contradicted.',
      ),
    );

    expect(result.canProceed, isTrue);
    expect(result.decision!.value, 'enabled');
    expect(result.gate.report, same(report));
  });
}
