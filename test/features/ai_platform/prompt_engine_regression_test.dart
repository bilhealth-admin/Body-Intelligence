import 'package:body_intelligence_log/features/ai_platform/domain/ai_coach_response.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/prompt_engine_policy.dart';
import 'package:body_intelligence_log/features/ai_platform/services/prompt_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('context projection is deterministic, bounded, and immutable', () {
    final engine = PromptEngine(
      policy: const PromptEnginePolicy(
        maximumContextLines: 2,
        maximumContextCharacters: 200,
      ),
    );
    final response = AiCoachResponse(
      status: AiCoachStatus.accepted,
      generatedAt: DateTime.utc(2026, 7, 24),
      headline: 'Action',
      message: 'Message',
      actionId: 'action-1',
      evidenceIds: const ['z', 'a', 'z'],
      uncertaintyNotes: const ['second', 'first'],
      safetyNotes: const ['safe'],
    );

    final first = engine.build(
      generatedAt: DateTime.utc(2026, 7, 24),
      coachResponse: response,
    );
    final second = engine.build(
      generatedAt: DateTime.utc(2026, 7, 24),
      coachResponse: response,
    );

    expect(first.contextLines, second.contextLines);
    expect(first.contextLines.length, 2);
    expect(first.evidenceIds, ['a', 'z']);
    expect(() => first.contextLines.add('mutation'), throwsUnsupportedError);
    expect(() => first.evidenceIds.add('mutation'), throwsUnsupportedError);
  });

  test('rejected coaching output cannot leak context or evidence', () {
    final result = const PromptEngine().build(
      generatedAt: DateTime.utc(2026, 7, 24),
      coachResponse: AiCoachResponse(
        status: AiCoachStatus.rejected,
        generatedAt: DateTime.utc(2026, 7, 24),
        headline: 'Rejected',
        message: 'Sensitive detail',
        actionId: null,
        evidenceIds: const ['must-not-leak'],
        uncertaintyNotes: const [],
        safetyNotes: const ['Safety rejection.'],
      ),
    );

    expect(result.canDispatch, isFalse);
    expect(result.contextLines, isEmpty);
    expect(result.evidenceIds, isEmpty);
  });
}
