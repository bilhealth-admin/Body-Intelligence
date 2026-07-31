import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TruthRuleComposer', () {
    const composer = TruthRuleComposer();
    final proposition = TruthProposition<_Context>(
      key: 'hydration.ready',
      description: 'Hydration evidence is currently supportive.',
      requiredEvidenceKeys: const ['water', 'symptoms'],
    );

    test('composes matching typed rules deterministically', () {
      final rules = <TruthRule<_Context>>[
        TruthRule<_Context>(
          key: 'symptoms.absent',
          propositionKey: proposition.key,
          direction: TruthSignalDirection.supports,
          strength: 0.7,
          reliability: 0.8,
          matches: (context) => !context.hasDehydrationSymptoms,
          evidence: (context) => AiEvidence(
            key: 'symptoms',
            description: 'No dehydration symptoms were logged.',
            source: 'daily_log',
            value: context.hasDehydrationSymptoms,
          ),
        ),
        TruthRule<_Context>(
          key: 'water.target',
          propositionKey: proposition.key,
          direction: TruthSignalDirection.supports,
          strength: 0.9,
          reliability: 1,
          matches: (context) => context.waterMl >= 3000,
          evidence: (context) => AiEvidence(
            key: 'water',
            description: 'Logged water met the local target.',
            source: 'daily_log',
            value: context.waterMl,
          ),
        ),
      ];

      final forward = composer.assess(
        proposition: proposition,
        context: const _Context(waterMl: 3200, hasDehydrationSymptoms: false),
        rules: rules,
      );
      final reverse = composer.assess(
        proposition: proposition,
        context: const _Context(waterMl: 3200, hasDehydrationSymptoms: false),
        rules: rules.reversed,
      );

      expect(forward.status, TruthAssessmentStatus.supported);
      expect(forward.score, reverse.score);
      expect(forward.confidence, reverse.confidence);
      expect(
        forward.evidence.map((item) => item.key),
        orderedEquals(['symptoms', 'water']),
      );
      expect(forward.missingEvidence, isEmpty);
    });

    test('reports required evidence not produced by matched rules', () {
      final assessment = composer.assess(
        proposition: proposition,
        context: const _Context(waterMl: 1200, hasDehydrationSymptoms: false),
        rules: [
          TruthRule<_Context>(
            key: 'water.target',
            propositionKey: proposition.key,
            direction: TruthSignalDirection.supports,
            strength: 1,
            reliability: 1,
            matches: (context) => context.waterMl >= 3000,
            evidence: (context) => AiEvidence(
              key: 'water',
              description: 'Logged water met the local target.',
              source: 'daily_log',
              value: context.waterMl,
            ),
          ),
        ],
      );

      expect(assessment.status, TruthAssessmentStatus.insufficientEvidence);
      expect(assessment.missingEvidence, ['symptoms', 'water']);
    });

    test('rejects duplicate rule keys and cross-proposition rules', () {
      TruthRule<_Context> rule(String key, String propositionKey) {
        return TruthRule<_Context>(
          key: key,
          propositionKey: propositionKey,
          direction: TruthSignalDirection.supports,
          strength: 1,
          reliability: 1,
          matches: (_) => true,
          evidence: (_) => AiEvidence(
            key: key,
            description: 'Deterministic evidence.',
            source: 'test',
          ),
        );
      }

      expect(
        () => composer.assess(
          proposition: proposition,
          context: const _Context(waterMl: 0, hasDehydrationSymptoms: false),
          rules: [rule('same', proposition.key), rule('same', proposition.key)],
        ),
        throwsArgumentError,
      );
      expect(
        () => composer.assess(
          proposition: proposition,
          context: const _Context(waterMl: 0, hasDehydrationSymptoms: false),
          rules: [rule('other', 'different.proposition')],
        ),
        throwsArgumentError,
      );
    });
  });
}

final class _Context {
  const _Context({required this.waterMl, required this.hasDehydrationSymptoms});

  final int waterMl;
  final bool hasDehydrationSymptoms;
}
