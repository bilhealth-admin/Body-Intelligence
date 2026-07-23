import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_explain_foundation_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_explain_foundation.dart';
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

  test('exposes one action through the stable Truth/Explain boundary', () {
    const foundation = TruthExplainFoundation();

    final result = foundation.evaluate<bool, String>(
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
            source: 'truth_explain_foundation_test',
          ),
        ),
      ],
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(result.status, TruthExplainFoundationStatus.action);
    expect(result.hasAction, isTrue);
    expect(result.decision, 'recover');
    expect(result.trustedResult.canExposeDecision, isTrue);
  });

  test('classifies safe abstention without exposing an action', () {
    const foundation = TruthExplainFoundation();

    final result = foundation.evaluate<bool, String>(
      proposition: proposition,
      context: false,
      rules: const <TruthRule<bool>>[],
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(result.status, TruthExplainFoundationStatus.abstention);
    expect(result.isAbstention, isTrue);
    expect(result.hasAction, isFalse);
    expect(result.decision, isNull);
    expect(result.trustedResult.isSafeAbstention, isTrue);
  });
}
