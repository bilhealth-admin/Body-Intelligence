import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/explainable_ai_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExplainableAiDecision.action', () {
    test('requires deterministic evidence and exposes one selected action', () {
      final decision = ExplainableAiDecision<String>.action(
        value: 'log_weight',
        summary: 'Log today\'s weight.',
        rationale: 'The latest daily weight observation is missing.',
        evidence: [
          AiEvidence(
            key: 'latest_weight_date',
            description: 'Latest locally stored weight date',
            source: 'WeightRepository',
            value: '2026-07-22',
          ),
        ],
        confidence: AiConfidenceLevel.high,
        alternatives: [
          AiDecisionAlternative(
            label: 'Do nothing',
            reasonNotChosen: 'A current observation is required first.',
          ),
        ],
      );

      expect(decision.hasAction, isTrue);
      expect(decision.value, 'log_weight');
      expect(decision.evidence.single.source, 'WeightRepository');
      expect(decision.alternatives, hasLength(1));
    });

    test('rejects an action without BIL-owned evidence', () {
      expect(
        () => ExplainableAiDecision<String>.action(
          value: 'drink_water',
          summary: 'Drink water.',
          rationale: 'Hydration is below target.',
          evidence: const [],
          confidence: AiConfidenceLevel.medium,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ExplainableAiDecision.abstain', () {
    test('identifies missing evidence and never invents an action', () {
      final decision = ExplainableAiDecision<String>.abstain(
        summary: 'No safe action is available.',
        rationale: 'The required daily evidence is incomplete.',
        missingEvidence: const ['today_weight', 'today_intake'],
      );

      expect(decision.hasAction, isFalse);
      expect(decision.value, isNull);
      expect(decision.confidence, AiConfidenceLevel.low);
      expect(decision.missingEvidence, ['today_weight', 'today_intake']);
    });

    test('requires a concrete missing-evidence explanation', () {
      expect(
        () => ExplainableAiDecision<String>.abstain(
          summary: 'Cannot decide.',
          rationale: 'Evidence is incomplete.',
          missingEvidence: const [],
        ),
        throwsArgumentError,
      );
    });
  });

  test('decision collections are immutable after construction', () {
    final evidence = <AiEvidence>[
      AiEvidence(
        key: 'water_total',
        description: 'Today\'s local water total',
        source: 'DailyLogRepository',
        value: 1200,
      ),
    ];
    final decision = ExplainableAiDecision<String>.action(
      value: 'drink_water',
      summary: 'Drink water.',
      rationale: 'Today\'s total is below the deterministic target.',
      evidence: evidence,
      confidence: AiConfidenceLevel.medium,
    );

    evidence.clear();

    expect(decision.evidence, hasLength(1));
    expect(() => decision.evidence.clear(), throwsUnsupportedError);
  });
}
