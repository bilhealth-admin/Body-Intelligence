import 'package:body_intelligence_log/features/ai_platform/domain/ai_evidence.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_assessment.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_conflict_analysis.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_report.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_evaluation_trace.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_integrity_result.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_proposition.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_rule.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/truth_signal.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_evaluation_validator.dart';
import 'package:body_intelligence_log/features/ai_platform/services/truth_rule_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = TruthEvaluationValidator();

  test('accepts a report emitted by TruthRuleComposer', () {
    final report = const TruthRuleComposer().report<int>(
      proposition: TruthProposition<int>(
        key: 'hydration.ready',
        description: 'Hydration evidence is ready.',
        requiredEvidenceKeys: const ['water.logged'],
      ),
      context: 2500,
      rules: [
        TruthRule<int>(
          key: 'water.rule',
          propositionKey: 'hydration.ready',
          direction: TruthSignalDirection.supports,
          strength: 0.8,
          reliability: 0.9,
          matches: (value) => value >= 2000,
          evidence: (value) => AiEvidence(
            key: 'water.logged',
            description: 'Logged water is $value ml.',
            source: 'daily_log',
            value: value,
          ),
        ),
      ],
    );

    final result = validator.validate(report);

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
  });

  test(
    'reports provenance, margin, status, direction, and evidence issues',
    () {
      final assessment = TruthAssessment(
        status: TruthAssessmentStatus.supported,
        score: -0.2,
        confidence: 0.8,
        rationale: 'Intentionally inconsistent fixture.',
        evidence: [
          AiEvidence(
            key: 'evidence.one',
            description: 'Fixture evidence.',
            source: 'test',
          ),
        ],
        missingEvidence: const [],
      );
      final report = TruthEvaluationReport(
        trace: TruthEvaluationTrace(
          propositionKey: 'fixture.proposition',
          consideredRuleKeys: const ['matched.rule', 'missing.rule'],
          matchedRuleKeys: const ['matched.rule', 'missing.rule'],
          assessment: assessment,
        ),
        conflict: TruthConflictAnalysis(
          status: TruthConflictStatus.supportDominant,
          supportingSignalKeys: const ['unexpected.rule'],
          opposingSignalKeys: const [],
          supportWeight: 0.7,
          oppositionWeight: 0.1,
          margin: 0.1,
          rationale: 'Intentionally inconsistent fixture.',
        ),
      );

      final result = validator.validate(report);

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((issue) => issue.code),
        containsAll(<TruthIntegrityIssueCode>{
          TruthIntegrityIssueCode.assessmentDirectionMismatch,
          TruthIntegrityIssueCode.conflictMarginMismatch,
          TruthIntegrityIssueCode.conflictSignalNotMatched,
          TruthIntegrityIssueCode.conflictStatusMismatch,
          TruthIntegrityIssueCode.evidenceCountMismatch,
          TruthIntegrityIssueCode.matchedRuleMissingFromConflict,
        }),
      );
    },
  );

  test('returns issues in deterministic code and subject order', () {
    final report = TruthEvaluationReport(
      trace: TruthEvaluationTrace(
        propositionKey: 'ordered.proposition',
        consideredRuleKeys: const ['b.rule', 'a.rule'],
        matchedRuleKeys: const ['b.rule', 'a.rule'],
        assessment: TruthAssessment(
          status: TruthAssessmentStatus.uncertain,
          score: 0,
          confidence: 0.5,
          rationale: 'Fixture.',
          evidence: [
            AiEvidence(
              key: 'fixture.evidence',
              description: 'Fixture.',
              source: 'test',
            ),
          ],
          missingEvidence: const [],
        ),
      ),
      conflict: TruthConflictAnalysis(
        status: TruthConflictStatus.none,
        supportingSignalKeys: const [],
        opposingSignalKeys: const [],
        supportWeight: 0,
        oppositionWeight: 0,
        margin: 0,
        rationale: 'Fixture.',
      ),
    );

    final first = validator
        .validate(report)
        .issues
        .map((issue) => '${issue.code.name}:${issue.subjectKey}')
        .toList();
    final second = validator
        .validate(report)
        .issues
        .map((issue) => '${issue.code.name}:${issue.subjectKey}')
        .toList();

    expect(first, second);
    expect(first, orderedEquals([...first]..sort()));
  });
}
