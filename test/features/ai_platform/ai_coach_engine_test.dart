import 'package:body_intelligence_log/features/ai_platform/domain/ai_coach_response.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_safety.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/automated_health_insight_summary.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/one_best_action.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_coach_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('composes a bounded coach response only from approved outputs', () {
    final candidate = OneBestActionCandidate(
      id: 'walk',
      title: 'Take a short walk',
      rationale: 'A short walk is the highest-ranked eligible action.',
      expectedBenefit: 0.8,
      confidence: 0.9,
      burden: 0.1,
      safetyEligible: true,
      evidenceIds: const ['action-evidence'],
    );
    final actionResult = OneBestActionResult(
      status: OneBestActionStatus.accepted,
      asOf: DateTime.utc(2026, 7, 24),
      selected: candidate,
      rankedCandidates: [
        RankedActionCandidate(
          candidate: candidate,
          rank: 1,
          score: candidate.rankingScore,
        ),
      ],
      reasons: const ['ranked first'],
      integrityIssues: const [],
    );
    final safety = AiSafetyResult(
      status: AiSafetyStatus.accepted,
      asOf: DateTime.utc(2026, 7, 24),
      actionResult: actionResult,
      issues: const [],
      reasons: const ['passed safety rules'],
    );
    final insight = AutomatedHealthInsightSummary(
      generatedAt: DateTime.utc(2026, 7, 24),
      title: 'Pattern',
      body: 'Your recent pattern is stable.',
      severity: HealthInsightSeverity.information,
      evidence: [
        HealthInsightEvidence(
          key: 'trend',
          statement: 'Stable trend.',
          provenance: 'body_twin',
          observedAt: DateTime.utc(2026, 7, 24),
          confidence: 0.9,
        ),
      ],
      uncertaintyNotes: const [],
      safetyApproved: true,
      isAbstained: false,
    );

    final result = const AiCoachEngine().coach(
      generatedAt: DateTime.utc(2026, 7, 24, 1),
      safetyResult: safety,
      insightSummary: insight,
    );

    expect(result.status, AiCoachStatus.accepted);
    expect(result.actionId, 'walk');
    expect(result.evidenceIds, ['action-evidence', 'trend']);
    expect(result.canProceed, isTrue);
  });
}
