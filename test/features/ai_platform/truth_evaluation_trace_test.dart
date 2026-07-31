import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TruthEvaluationTrace', () {
    final proposition = TruthProposition<_Context>(
      key: 'recovery.ready',
      description: 'Recovery evidence supports normal activity.',
      requiredEvidenceKeys: const ['sleep'],
    );
    const composer = TruthRuleComposer();

    test('records stable considered, matched, and unmatched rule keys', () {
      final rules = [
        _rule(
          key: 'sleep.sufficient',
          propositionKey: proposition.key,
          matches: (context) => context.sleepHours >= 7,
        ),
        _rule(
          key: 'symptoms.absent',
          propositionKey: proposition.key,
          matches: (context) => !context.hasSymptoms,
        ),
      ];

      final trace = composer.trace(
        proposition: proposition,
        context: const _Context(sleepHours: 8, hasSymptoms: true),
        rules: rules.reversed,
      );

      expect(trace.propositionKey, proposition.key);
      expect(
        trace.consideredRuleKeys,
        orderedEquals(['sleep.sufficient', 'symptoms.absent']),
      );
      expect(trace.matchedRuleKeys, ['sleep.sufficient']);
      expect(trace.unmatchedRuleKeys, ['symptoms.absent']);
      expect(trace.assessment.status, TruthAssessmentStatus.supported);
    });

    test('trace collections are immutable and reject invalid provenance', () {
      final trace = composer.trace(
        proposition: proposition,
        context: const _Context(sleepHours: 8, hasSymptoms: false),
        rules: [
          _rule(
            key: 'sleep.sufficient',
            propositionKey: proposition.key,
            matches: (_) => true,
          ),
        ],
      );

      expect(
        () => trace.consideredRuleKeys.add('other'),
        throwsUnsupportedError,
      );
      expect(() => trace.matchedRuleKeys.clear(), throwsUnsupportedError);
    });
  });
}

TruthRule<_Context> _rule({
  required String key,
  required String propositionKey,
  required bool Function(_Context context) matches,
}) {
  return TruthRule<_Context>(
    key: key,
    propositionKey: propositionKey,
    direction: TruthSignalDirection.supports,
    strength: 1,
    reliability: 1,
    matches: matches,
    evidence: (context) => AiEvidence(
      key: key == 'sleep.sufficient' ? 'sleep' : 'symptoms',
      description: 'Deterministic local evidence.',
      source: 'test',
      value: context.sleepHours,
    ),
  );
}

final class _Context {
  const _Context({required this.sleepHours, required this.hasSymptoms});

  final int sleepHours;
  final bool hasSymptoms;
}
