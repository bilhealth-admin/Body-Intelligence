import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/trusted_truth_decision_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final proposition = TruthProposition<bool>(
    key: 'recovery.ready',
    description: 'Local evidence supports recovery.',
  );
  final supported = TruthDecisionCandidate<String>(
    value: 'recover',
    label: 'Recover',
    summary: 'Prioritize recovery.',
    reasonWhenNotChosen: 'Evidence did not support recovery.',
  );
  final contradicted = TruthDecisionCandidate<String>(
    value: 'continue',
    label: 'Continue',
    summary: 'Continue the current plan.',
    reasonWhenNotChosen: 'Evidence did not contradict recovery.',
  );

  test(
    'exposes a decision only after the complete trusted chain accepts it',
    () {
      const pipeline = TrustedTruthDecisionPipeline();

      final result = pipeline.evaluate<bool, String>(
        proposition: proposition,
        context: true,
        rules: <TruthRule<bool>>[
          TruthRule<bool>(
            key: 'recovery.supported',
            propositionKey: proposition.key,
            direction: TruthSignalDirection.supports,
            strength: 1,
            reliability: 1,
            matches: (value) => value,
            evidence: (_) => AiEvidence(
              key: 'recovery.local',
              description: 'Local recovery observation.',
              source: 'trusted_truth_decision_pipeline_test',
            ),
          ),
        ],
        supportedCandidate: supported,
        contradictedCandidate: contradicted,
      );

      expect(result.canProceed, isTrue);
      expect(result.canExposeDecision, isTrue);
      expect(result.decision, 'recover');
      expect(result.gate.integrity.isValid, isTrue);
    },
  );

  test('preserves safe abstention without exposing a decision', () {
    const pipeline = TrustedTruthDecisionPipeline();

    final result = pipeline.evaluate<bool, String>(
      proposition: proposition,
      context: false,
      rules: const <TruthRule<bool>>[],
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(result.canProceed, isTrue);
    expect(result.isSafeAbstention, isTrue);
    expect(result.isSafeRejection, isFalse);
    expect(result.canExposeDecision, isFalse);
    expect(result.decision, isNull);
  });
}
