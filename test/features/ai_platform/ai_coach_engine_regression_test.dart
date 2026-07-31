import 'package:body_intelligence_log/features/ai_platform/domain/ai_coach_response.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/ai_safety.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/automated_health_insight_summary.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/one_best_action.dart';
import 'package:body_intelligence_log/features/ai_platform/services/ai_coach_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('never exposes an action when safety rejects upstream output', () {
    final actionResult = OneBestActionResult(
      status: OneBestActionStatus.rejected,
      asOf: DateTime.utc(2026, 7, 24),
      selected: null,
      rankedCandidates: const [],
      reasons: const ['rejected'],
      integrityIssues: const ['unsafe'],
    );
    final safety = AiSafetyResult(
      status: AiSafetyStatus.rejected,
      asOf: DateTime.utc(2026, 7, 24),
      actionResult: actionResult,
      issues: const [],
      reasons: const ['blocked'],
    );
    final insight = AutomatedHealthInsightSummary(
      generatedAt: DateTime.utc(2026, 7, 24),
      title: 'No insight',
      body: 'Insufficient trusted evidence.',
      severity: HealthInsightSeverity.blocked,
      evidence: const [],
      uncertaintyNotes: const ['insufficient evidence'],
      safetyApproved: false,
      isAbstained: true,
    );

    final result = const AiCoachEngine().coach(
      generatedAt: DateTime.utc(2026, 7, 24, 1),
      safetyResult: safety,
      insightSummary: insight,
    );

    expect(result.status, AiCoachStatus.rejected);
    expect(result.actionId, isNull);
    expect(result.canProceed, isFalse);
  });
}
