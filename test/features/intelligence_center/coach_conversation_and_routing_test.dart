import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_intent_normalizer.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('analysis questions are not hijacked by logging navigation', () {
    const parser = LocalCoachCommandParser();
    expect(parser.parse('Analyze my weight plateau', locale: 'en'), isEmpty);
    expect(parser.parse('Review my food day', locale: 'en'), isEmpty);
    expect(
      parser.parse('Why did my workout performance drop?', locale: 'en'),
      isEmpty,
    );
    expect(parser.parse('حلل ثبات وزني هذا الأسبوع', locale: 'ar'), isEmpty);

    expect(parser.parse('Open my weight log', locale: 'en'), isNotEmpty);
    expect(parser.parse('Log weight 82 kg', locale: 'en'), isNotEmpty);
    expect(parser.parse('I ate chicken and rice', locale: 'en'), isNotEmpty);
    expect(parser.parse('Open workouts', locale: 'en'), isNotEmpty);
  });

  test(
    'model receives bounded multi-turn conversation and metadata returns',
    () async {
      final gateway = _RecordingGateway();
      final api = ModelBackedLocalCoachApi(
        gateway: gateway,
        context: CoachContextSnapshot.empty(),
      );
      final result = await api.understand(
        const LocalCoachRequest(
          text: 'Why is that happening?',
          locale: 'en',
          conversation: [
            CoachConversationTurn(
              role: 'user',
              content: 'My weight is stable.',
            ),
            CoachConversationTurn(
              role: 'assistant',
              content: 'Let us inspect the trend.',
            ),
          ],
        ),
      );

      expect(gateway.conversation, hasLength(2));
      expect(gateway.conversation.last.role, 'assistant');
      expect(gateway.languageDetected, isFalse);
      expect(result.answer, 'Grounded follow-up');
      expect(result.runtime, CoachAnswerRuntime.cloudPersonalized);
      expect(result.confidence, .9);
      expect(result.evidence, ['canonicalIntelligence.plateauRisk']);
      expect(result.responseId, 'coach-correlated-request-01');
    },
  );

  test('native speech language hint reaches the model gateway', () async {
    final gateway = _RecordingGateway();
    final api = ModelBackedLocalCoachApi(
      gateway: gateway,
      context: CoachContextSnapshot.empty(),
    );

    await api.understand(
      const LocalCoachRequest(
        text: 'protein 30 g',
        locale: 'el-GR',
        languageDetected: true,
      ),
    );

    expect(gateway.languageDetected, isTrue);
    expect(gateway.locale, 'el-GR');
  });

  test(
    'recognized voice reaches the text parser without an audio payload',
    () async {
      final gateway = _RecordingGateway();
      final api = ModelBackedLocalCoachApi(
        gateway: gateway,
        context: CoachContextSnapshot.empty(),
      );
      final result = await api.understand(
        const LocalCoachRequest(
          text: 'Log weight 82 kg',
          locale: 'en',
          channel: CoachInputChannel.voice,
        ),
      );

      expect(result.actions, isNotEmpty);
      expect(gateway.conversation, isEmpty);
    },
  );

  test('consented model is preferred over local greeting fallback', () async {
    final gateway = _RecordingGateway();
    final engine = IntelligenceCenterEngine(
      localApi: ModelBackedLocalCoachApi(
        gateway: gateway,
        context: CoachContextSnapshot.empty(),
      ),
    );

    final reply = await engine.answer(
      question: 'assalamualaikum',
      arabic: false,
      localeCode: 'en',
      detectedLanguageTag: 'ar-SA',
    );

    expect(reply.message.text, 'Grounded follow-up');
    expect(reply.runtime, CoachAnswerRuntime.cloudPersonalized);
    expect(gateway.languageDetected, isTrue);
    expect(gateway.locale, 'ar-SA');
  });

  test(
    'context v2 includes canonical intelligence and explicit memory slots',
    () {
      final context = CoachContextSnapshot(
        generatedAt: DateTime.utc(2026, 8, 20),
        profile: const {},
        weights: const [],
        nutritionDays: const [],
        waterHistory: const [],
        computedHealth: const {},
        canonicalIntelligence: const {'status': 'accepted'},
        decisionMemory: const [
          {'recommendationKey': 'increaseProtein', 'response': 'dismissed'},
        ],
        explicitMemories: const [
          {'text': 'I prefer evening workouts'},
        ],
      ).toJson();

      expect(context['schema'], 'bil.coach-context.v2');
      expect(context['canonicalIntelligence'], {'status': 'accepted'});
      expect(context['decisionMemory'], isNotEmpty);
      expect(context['explicitMemories'], isNotEmpty);
    },
  );
}

class _RecordingGateway implements LocalModelGateway {
  List<CoachConversationTurn> conversation = const [];
  bool languageDetected = false;
  String? locale;

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    this.conversation = conversation;
    this.languageDetected = languageDetected;
    this.locale = locale;
    return LocalModelResult.answer(
      LocalModelAnswer(
        text: 'Grounded follow-up',
        action: null,
        processedOnDevice: false,
        reason: 'Canonical trend is stable.',
        confidence: .9,
        evidence: ['canonicalIntelligence.plateauRisk'],
        responseId: 'coach-correlated-request-01',
        transcript: null,
      ),
    );
  }
}
