import 'package:body_intelligence_log/features/ai_platform/domain/ai_safety.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_safety_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/one_best_action.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_safety_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final action = OneBestActionCandidate(
    id: 'walk',
    title: 'Walk',
    rationale: 'Supported local action',
    expectedBenefit: 0.8,
    confidence: 0.9,
    burden: 0.2,
    safetyEligible: true,
    evidenceIds: const ['e1'],
  );
  OneBestActionResult accepted() => OneBestActionResult(
    status: OneBestActionStatus.accepted,
    asOf: DateTime.utc(2026, 7, 24),
    selected: action,
    rankedCandidates: [
      RankedActionCandidate(candidate: action, rank: 1, score: 0.7),
    ],
    reasons: const ['ranked'],
    integrityIssues: const [],
  );

  test('accepts action when no blocking rule matches', () {
    final result = const AiSafetyEngine().evaluate(
      actionResult: accepted(),
      policy: AiSafetyPolicy(rules: const []),
    );
    expect(result.status, AiSafetyStatus.accepted);
    expect(result.canProceed, isTrue);
  });

  test('rejects action when a hard caller-owned rule matches', () {
    final result = const AiSafetyEngine().evaluate(
      actionResult: accepted(),
      policy: AiSafetyPolicy(
        rules: [
          AiSafetyRule(
            id: 'blocked',
            description: 'blocked by caller policy',
            severity: AiSafetySeverity.blocking,
            matches: (_) => true,
          ),
        ],
      ),
    );
    expect(result.status, AiSafetyStatus.rejected);
    expect(result.acceptedAction, isNull);
  });
}
