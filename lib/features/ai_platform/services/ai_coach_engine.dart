import '../domain/ai_coach_policy.dart';
import '../domain/ai_coach_response.dart';
import '../domain/ai_safety.dart';
import '../domain/automated_health_insight_summary.dart';
import 'ai_coach_integrity_validator.dart';

/// Deterministic local coach boundary over safety-approved action and bounded insight output.
///
/// This engine does not generate clinical advice, call providers, mutate user state,
/// or invent evidence. It only composes repository-owned trusted outputs.
final class AiCoachEngine {
  const AiCoachEngine({
    this.policy = const AiCoachPolicy(),
    this.integrityValidator = const AiCoachIntegrityValidator(),
  });

  final AiCoachPolicy policy;
  final AiCoachIntegrityValidator integrityValidator;

  AiCoachResponse coach({
    required DateTime generatedAt,
    required AiSafetyResult safetyResult,
    required AutomatedHealthInsightSummary insightSummary,
  }) {
    if (!safetyResult.canProceed) {
      return _validated(
        AiCoachResponse(
          status: AiCoachStatus.rejected,
          generatedAt: generatedAt,
          headline: 'No safe coaching action available',
          message:
              'BIL did not expose an action because the safety boundary did not approve one.',
          actionId: null,
          evidenceIds: const [],
          uncertaintyNotes: insightSummary.uncertaintyNotes,
          safetyNotes: <String>[
            ...safetyResult.reasons,
            ...safetyResult.issues.map((issue) => issue.description),
          ],
        ),
      );
    }

    if (policy.requireInsightSummary && insightSummary.isAbstained) {
      return _validated(
        AiCoachResponse(
          status: AiCoachStatus.abstained,
          generatedAt: generatedAt,
          headline: 'More trusted context is needed',
          message:
              'BIL has a safety-approved action but abstained from coaching because no trusted insight summary is available.',
          actionId: null,
          evidenceIds: const [],
          uncertaintyNotes: insightSummary.uncertaintyNotes,
          safetyNotes: safetyResult.reasons,
        ),
      );
    }

    final action = safetyResult.acceptedAction!;
    final body =
        '${insightSummary.body.trim()} ${action.title.trim()}: ${action.rationale.trim()}'
            .trim();
    final bounded = body.length <= policy.maximumMessageCharacters
        ? body
        : '${body.substring(0, policy.maximumMessageCharacters - 1).trimRight()}…';
    return _validated(
      AiCoachResponse(
        status: AiCoachStatus.accepted,
        generatedAt: generatedAt,
        headline: action.title,
        message: bounded,
        actionId: action.id,
        evidenceIds: <String>{
          ...action.evidenceIds,
          ...insightSummary.evidence.map((item) => item.key),
        },
        uncertaintyNotes: insightSummary.uncertaintyNotes,
        safetyNotes: safetyResult.reasons,
      ),
    );
  }

  AiCoachResponse _validated(AiCoachResponse response) {
    final issues = integrityValidator.validate(response);
    if (issues.isEmpty) {
      return response;
    }
    return AiCoachResponse(
      status: AiCoachStatus.rejected,
      generatedAt: response.generatedAt,
      headline: 'AI Coach integrity rejection',
      message:
          'BIL rejected the coaching response because its integrity contract was not satisfied.',
      actionId: null,
      evidenceIds: const [],
      uncertaintyNotes: response.uncertaintyNotes,
      safetyNotes: <String>[...response.safetyNotes, ...issues],
    );
  }
}
