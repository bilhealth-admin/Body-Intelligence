import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_conflict_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const composer = TruthRuleComposer();

  test('report joins trace, assessment, and conflict analysis', () {
    final report = composer.report<int>(
      proposition: _proposition(),
      context: 7,
      rules: [
        _rule(
          key: 'support.rule',
          direction: TruthSignalDirection.supports,
          strength: 0.9,
        ),
        _rule(
          key: 'oppose.rule',
          direction: TruthSignalDirection.opposes,
          strength: 0.2,
        ),
      ],
    );

    expect(report.trace.propositionKey, 'truth.proposition');
    expect(report.trace.matchedRuleKeys, ['oppose.rule', 'support.rule']);
    expect(report.assessment, same(report.trace.assessment));
    expect(report.assessment.status, TruthAssessmentStatus.supported);
    expect(report.conflict.status, TruthConflictStatus.supportDominant);
    expect(report.conflict.supportingSignalKeys, ['support.rule']);
    expect(report.conflict.opposingSignalKeys, ['oppose.rule']);
    expect(report.abstains, isFalse);
  });

  test('each rule is evaluated once while producing the full report', () {
    var evaluations = 0;
    final rule = TruthRule<int>(
      key: 'counted.rule',
      propositionKey: 'truth.proposition',
      direction: TruthSignalDirection.supports,
      matches: (_) {
        evaluations += 1;
        return true;
      },
      evidence: (_) => AiEvidence(
        key: 'required.evidence',
        description: 'Locally observed evidence.',
        source: 'truth_rule_composer',
      ),
      strength: 0.8,
      reliability: 1,
    );

    final report = composer.report<int>(
      proposition: _proposition(),
      context: 1,
      rules: [rule],
    );

    expect(evaluations, 1);
    expect(report.assessment.status, TruthAssessmentStatus.supported);
    expect(report.conflict.status, TruthConflictStatus.none);
  });

  test('uncertain and insufficient assessments are explicit abstentions', () {
    final uncertain = composer.report<int>(
      proposition: _proposition(),
      context: 1,
      rules: [
        _rule(
          key: 'balanced.support',
          direction: TruthSignalDirection.supports,
          strength: 0.6,
        ),
        _rule(
          key: 'balanced.oppose',
          direction: TruthSignalDirection.opposes,
          strength: 0.6,
        ),
      ],
    );
    final insufficient = composer.report<int>(
      proposition: _proposition(),
      context: 1,
      rules: const [],
    );

    expect(uncertain.assessment.status, TruthAssessmentStatus.uncertain);
    expect(uncertain.abstains, isTrue);
    expect(
      insufficient.assessment.status,
      TruthAssessmentStatus.insufficientEvidence,
    );
    expect(insufficient.abstains, isTrue);
  });

  test('report is deterministic regardless of input rule order', () {
    final support = _rule(
      key: 'z.support',
      direction: TruthSignalDirection.supports,
      strength: 0.8,
    );
    final oppose = _rule(
      key: 'a.oppose',
      direction: TruthSignalDirection.opposes,
      strength: 0.1,
    );

    final left = composer.report<int>(
      proposition: _proposition(),
      context: 1,
      rules: [support, oppose],
    );
    final right = composer.report<int>(
      proposition: _proposition(),
      context: 1,
      rules: [oppose, support],
    );

    expect(right.trace.consideredRuleKeys, left.trace.consideredRuleKeys);
    expect(right.trace.matchedRuleKeys, left.trace.matchedRuleKeys);
    expect(right.assessment.status, left.assessment.status);
    expect(right.assessment.confidence, left.assessment.confidence);
    expect(right.conflict.status, left.conflict.status);
    expect(right.conflict.rationale, left.conflict.rationale);
  });
}

TruthProposition<int> _proposition() {
  return TruthProposition<int>(
    key: 'truth.proposition',
    description: 'A deterministic proposition for testing.',
    requiredEvidenceKeys: const ['required.evidence'],
  );
}

TruthRule<int> _rule({
  required String key,
  required TruthSignalDirection direction,
  required double strength,
}) {
  return TruthRule<int>(
    key: key,
    propositionKey: 'truth.proposition',
    direction: direction,
    matches: (_) => true,
    evidence: (_) => AiEvidence(
      key: 'required.evidence',
      description: 'Locally observed evidence.',
      source: 'truth_rule_composer',
    ),
    strength: strength,
    reliability: 1,
  );
}
