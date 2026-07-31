import 'package:body_intelligence_log/features/ai_platform/domain/ai_coach_response.dart';
import 'package:body_intelligence_log/features/ai_platform/domain/prompt_envelope.dart';
import 'package:body_intelligence_log/features/ai_platform/services/prompt_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'builds a bounded provider-neutral prompt from approved coaching output',
    () {
      final result = const PromptEngine().build(
        generatedAt: DateTime.utc(2026, 7, 24),
        coachResponse: AiCoachResponse(
          status: AiCoachStatus.accepted,
          generatedAt: DateTime.utc(2026, 7, 24),
          headline: 'Keep today consistent',
          message: 'Repeat the already approved action.',
          actionId: 'action-1',
          evidenceIds: const ['evidence-b', 'evidence-a'],
          uncertaintyNotes: const ['Weight noise remains possible.'],
          safetyNotes: const ['Stop when safety status changes.'],
        ),
      );

      expect(result.status, PromptEnvelopeStatus.ready);
      expect(result.canDispatch, isTrue);
      expect(result.evidenceIds, ['evidence-a', 'evidence-b']);
      expect(result.contextLines, hasLength(3));
      expect(result.systemInstruction, contains('Do not invent'));
      expect(result.safetyRequirements, isNotEmpty);
    },
  );

  test('does not dispatch when coach abstains', () {
    final result = const PromptEngine().build(
      generatedAt: DateTime.utc(2026, 7, 24),
      coachResponse: AiCoachResponse(
        status: AiCoachStatus.abstained,
        generatedAt: DateTime.utc(2026, 7, 24),
        headline: 'More context needed',
        message: 'No action exposed.',
        actionId: null,
        evidenceIds: const [],
        uncertaintyNotes: const ['Missing trusted context.'],
        safetyNotes: const ['Do not act.'],
      ),
    );

    expect(result.status, PromptEnvelopeStatus.abstained);
    expect(result.canDispatch, isFalse);
    expect(result.contextLines, isEmpty);
  });
}
