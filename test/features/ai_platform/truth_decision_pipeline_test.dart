import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_decision_candidate.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_decision_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final proposition = TruthProposition<bool>(
    key: 'hydration.ready',
    description: 'Hydration evidence supports the local action.',
  );
  final supported = TruthDecisionCandidate<String>(
    value: 'drink_water',
    label: 'Drink water',
    summary: 'Drink water now.',
    reasonWhenNotChosen: 'Truth evidence did not support hydration.',
  );
  final contradicted = TruthDecisionCandidate<String>(
    value: 'hold',
    label: 'Hold',
    summary: 'Do not add water now.',
    reasonWhenNotChosen: 'Truth evidence did not contradict hydration.',
  );

  test('exposes a validated action from one deterministic evaluation', () {
    const pipeline = TruthDecisionPipeline();
    final result = pipeline.evaluate<bool, String>(
      proposition: proposition,
      context: true,
      rules: <TruthRule<bool>>[
        TruthRule<bool>(
          key: 'hydration.supported',
          propositionKey: proposition.key,
          direction: TruthSignalDirection.supports,
          strength: 1,
          reliability: 1,
          matches: (value) => value,
          evidence: (_) => AiEvidence(
            key: 'water.local',
            description: 'Local hydration observation.',
            source: 'truth_decision_pipeline_test',
          ),
        ),
      ],
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(result.report.trace.propositionKey, proposition.key);
    expect(result.canExposeDecision, isTrue);
    expect(result.validation.decisionResult.decision?.value, 'drink_water');
    expect(result.validation.integrity.isValid, isTrue);
  });

  test('preserves safe abstention when evidence is insufficient', () {
    const pipeline = TruthDecisionPipeline();
    final result = pipeline.evaluate<bool, String>(
      proposition: TruthProposition<bool>(
        key: 'hydration.missing',
        description: 'Required evidence is missing.',
        requiredEvidenceKeys: const <String>['water.required'],
      ),
      context: false,
      rules: const <TruthRule<bool>>[],
      supportedCandidate: supported,
      contradictedCandidate: contradicted,
    );

    expect(result.canExposeDecision, isTrue);
    expect(result.validation.decisionResult.decision?.hasAction, isFalse);
    expect(
      result.validation.decisionResult.decision?.missingEvidence,
      contains('water.required'),
    );
  });
}
