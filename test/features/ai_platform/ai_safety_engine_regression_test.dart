import 'package:body_intelligence_log/features/ai_platform/domain/ai_safety.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_safety_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/one_best_action.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_safety_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('never exposes action when upstream action result abstains', () {
    final upstream = OneBestActionResult(
      status: OneBestActionStatus.abstained,
      asOf: DateTime.utc(2026, 7, 24),
      selected: null,
      rankedCandidates: const [],
      reasons: const ['none'],
      integrityIssues: const [],
    );
    final result = const AiSafetyEngine().evaluate(
      actionResult: upstream,
      policy: AiSafetyPolicy(rules: const []),
    );
    expect(result.status, AiSafetyStatus.rejected);
    expect(result.acceptedAction, isNull);
  });

  test('issue ordering is deterministic', () {
    final action = OneBestActionCandidate(
      id: 'a',
      title: 'A',
      rationale: 'R',
      expectedBenefit: 1,
      confidence: 1,
      burden: 0,
      safetyEligible: true,
      evidenceIds: const ['e'],
    );
    final upstream = OneBestActionResult(
      status: OneBestActionStatus.accepted,
      asOf: DateTime.utc(2026, 7, 24),
      selected: action,
      rankedCandidates: [
        RankedActionCandidate(candidate: action, rank: 1, score: 1),
      ],
      reasons: const ['ranked'],
      integrityIssues: const [],
    );
    final result = const AiSafetyEngine().evaluate(
      actionResult: upstream,
      policy: AiSafetyPolicy(
        rules: [
          AiSafetyRule(
            id: 'z',
            description: 'z',
            severity: AiSafetySeverity.advisory,
            matches: (_) => true,
          ),
          AiSafetyRule(
            id: 'a',
            description: 'a',
            severity: AiSafetySeverity.advisory,
            matches: (_) => true,
          ),
        ],
      ),
    );
    expect(result.issues.map((issue) => issue.ruleId), ['a', 'z']);
  });
}
