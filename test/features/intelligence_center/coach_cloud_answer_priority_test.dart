import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'model-backed personal lookup reaches the cloud before local shortcut',
    () async {
      final gateway = _RecordingGateway(
        const LocalModelResult.answer(
          LocalModelAnswer(
            text:
                'Your recent trend is stable; here is what it means for your plan.',
            action: null,
            processedOnDevice: false,
          ),
        ),
      );
      final response = await _modelEngine(gateway).answer(
        question: 'What is my weight?',
        arabic: false,
        localeCode: 'en',
        coachContext: _context,
      );

      expect(gateway.calls, 1);
      expect(response.message.text, contains('recent trend'));
      expect(response.message.text, isNot(contains('82.7')));
      expect(response.runtime, CoachAnswerRuntime.cloudPersonalized);
    },
  );

  test(
    'sleep coaching is model-backed instead of an on-device early return',
    () async {
      final gateway = _RecordingGateway(
        const LocalModelResult.answer(
          LocalModelAnswer(
            text:
                'Your sleep target should be discussed with the rest of your recovery pattern.',
            action: null,
            processedOnDevice: false,
          ),
        ),
      );
      final engine = _modelEngine(gateway);

      expect(
        engine.canAnswerWithoutPersonalContext('How much should I sleep?'),
        isFalse,
      );
      final response = await engine.answer(
        question: 'How much should I sleep?',
        arabic: false,
        localeCode: 'en',
      );

      expect(gateway.calls, 1);
      expect(response.message.text, contains('recovery pattern'));
      expect(response.message.text, isNot(contains('Most adults need')));
    },
  );

  test('cloud answer and model action are presented together', () async {
    final gateway = _RecordingGateway(
      const LocalModelResult.answer(
        LocalModelAnswer(
          text:
              'Your meals support the plan; review the log for the next choice.',
          action: {'name': 'open_meals', 'arguments': <String, Object?>{}},
          processedOnDevice: false,
        ),
      ),
    );
    final response = await _modelEngine(gateway).answer(
      question: 'Why am I hungry after training?',
      arabic: false,
      localeCode: 'en',
      conversation: const [
        CoachConversationTurn(role: 'user', content: 'I trained today.'),
        CoachConversationTurn(
          role: 'assistant',
          content: 'Tell me about hunger.',
        ),
      ],
    );

    expect(response.message.text, contains('support the plan'));
    expect(response.actions, hasLength(1));
    expect(response.actions.single.type, IntelligenceActionType.reviewMeal);
    expect(gateway.conversation, hasLength(2));
  });

  test(
    'cloud failure is a retryable service state, not local success',
    () async {
      final gateway = _RecordingGateway(
        const LocalModelResult(
          status: CoachServiceStatus.temporarilyUnavailable,
          diagnosticCode: 'cloud_request_failed',
        ),
      );
      final response = await _modelEngine(gateway).answer(
        question: 'Why is my progress slow?',
        arabic: false,
        localeCode: 'en',
        coachContext: _context,
      );

      expect(response.serviceStatus, CoachServiceStatus.temporarilyUnavailable);
      expect(response.runtime, CoachAnswerRuntime.localFallback);
      expect(response.message.text, contains('temporarily unavailable'));
      expect(
        response.message.text,
        isNot(contains('I understood your request locally')),
      );
    },
  );
}

IntelligenceCenterEngine _modelEngine(_RecordingGateway gateway) =>
    IntelligenceCenterEngine(
      localApi: ModelBackedLocalCoachApi(gateway: gateway, context: _context),
    );

final _context = CoachContextSnapshot(
  generatedAt: DateTime.utc(2026, 9, 20),
  profile: const {'currentWeightKg': 83.4},
  weights: [CoachWeightPoint(at: DateTime.utc(2026, 9, 19), kg: 82.7)],
  nutritionDays: const [],
  waterHistory: const [],
  computedHealth: const {},
);

final class _RecordingGateway implements LocalModelGateway {
  _RecordingGateway(this.result);

  final LocalModelResult result;
  int calls = 0;
  List<CoachConversationTurn> conversation = const [];

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    calls += 1;
    this.conversation = conversation;
    return result;
  }
}
