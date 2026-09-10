import 'dart:io';

import 'package:body_intelligence_log/app/services/runtime_permission_policy.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_action.dart';
import 'package:body_intelligence_log/features/intelligence_center/presentation/intelligence_center_page.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_api.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_intent_normalizer.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_coach_command_parser.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/local_model_gateway.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/intelligence_center_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed confirmation resolves only an exact pending-action decision', () {
    expect(
      coachPendingActionDecision('تأكيد'),
      CoachPendingActionDecision.confirm,
    );
    expect(
      coachPendingActionDecision('نعم؟'),
      CoachPendingActionDecision.confirm,
    );
    expect(
      coachPendingActionDecision('cancel it'),
      CoachPendingActionDecision.cancel,
    );
    expect(
      coachPendingActionDecision('نعم اشرح لي الخطة'),
      CoachPendingActionDecision.none,
    );
  });

  test('iOS voice permission recovery identifies the exact permission', () {
    expect(
      coachRuntimePermissionSequence(
        capability: BilRuntimeCapability.microphone,
        includeSpeechRecognition: true,
        platform: TargetPlatform.iOS,
      ),
      const [
        BilRuntimeCapability.microphone,
        BilRuntimeCapability.speechRecognition,
      ],
    );
    expect(
      coachRuntimePermissionSequence(
        capability: BilRuntimeCapability.microphone,
        includeSpeechRecognition: true,
        platform: TargetPlatform.android,
      ),
      const [BilRuntimeCapability.microphone],
    );

    final speech = coachRuntimePermissionPresentation(
      BilRuntimeCapability.speechRecognition,
    );
    expect(speech.englishName, 'speech recognition');
    expect(speech.arabicName, 'التعرف على الكلام');
    expect(speech.englishRationale, contains('text is sent after you pause'));
    expect(speech.englishRationale, isNot(contains('review the text')));
    expect(speech.englishRationale, isNot(contains('camera')));
  });

  test('local and cloud prompts publish the same goal argument contract', () {
    final localPrompt = File(
      'lib/features/intelligence_center/services/local_model_gateway_io.dart',
    ).readAsStringSync();
    final cloudPrompt = File(
      'supabase/functions/ai-coach/server.ts',
    ).readAsStringSync();

    for (final source in [localPrompt, cloudPrompt]) {
      expect(
        source,
        contains(
          'update_goal {"targetWeightKg":number,"targetDate"?:"YYYY-MM-DD"}',
        ),
      );
      expect(source, contains('because BIL presents the confirmation UI'));
    }
    expect(cloudPrompt, contains(r'${toolArgumentContract} ${systemCore}'));
  });

  test('stale conversation saves cannot replace a selected chat', () {
    expect(
      coachConversationSaveIsCurrent(
        saveEpoch: 3,
        currentEpoch: 4,
        saveConversationId: 'old-chat',
        activeConversationId: 'new-chat',
      ),
      isFalse,
    );
    expect(
      coachConversationSaveIsCurrent(
        saveEpoch: 4,
        currentEpoch: 4,
        saveConversationId: 'old-chat',
        activeConversationId: 'new-chat',
      ),
      isFalse,
    );
    expect(
      coachConversationSaveIsCurrent(
        saveEpoch: 4,
        currentEpoch: 4,
        saveConversationId: 'new-chat',
        activeConversationId: 'new-chat',
      ),
      isTrue,
    );
  });

  test(
    'conversation history updates a stable chat instead of duplicating it',
    () {
      final history = <Map<String, Object?>>[
        {
          'id': 'conversation-1',
          'title': 'Original title',
          'createdAt': '2026-09-01T10:00:00.000Z',
          'messages': const <Object?>[
            {'role': 'user', 'text': 'Old turn'},
          ],
        },
        {
          'id': 'conversation-2',
          'title': 'Other chat',
          'createdAt': '2026-09-02T10:00:00.000Z',
          'messages': const <Object?>[],
        },
      ];

      final updated = upsertCoachConversationHistory(
        history: history,
        id: 'conversation-1',
        title: 'Updated title',
        createdAt: '2026-09-04T10:00:00.000Z',
        messages: const <Object?>[
          {'role': 'user', 'text': 'Old turn'},
          {'role': 'bil', 'text': 'New reply'},
        ],
      );

      expect(updated, hasLength(2));
      expect(updated.first['id'], 'conversation-1');
      expect(updated.first['title'], 'Updated title');
      expect(updated.first['createdAt'], '2026-09-01T10:00:00.000Z');
      expect(updated.first['messages'], hasLength(2));
    },
  );

  test(
    'only exact AI credit exhaustion maps to the purchase-required state',
    () {
      expect(
        coachServiceStatusForFunctionError(402, 'ai_usage_exhausted'),
        CoachServiceStatus.creditsRequired,
      );
      for (final code in <String?>[
        null,
        'quota_exhausted',
        'AI_USAGE_EXHAUSTED',
        'ai_usage_exhausted ',
      ]) {
        expect(
          coachServiceStatusForFunctionError(402, code),
          CoachServiceStatus.quotaExhausted,
        );
      }
      expect(
        coachServiceStatusForFunctionError(500, 'ai_usage_exhausted'),
        CoachServiceStatus.temporarilyUnavailable,
      );
    },
  );

  test('only exact safety block envelope disables speech and retry', () {
    expect(
      coachServiceStatusForFunctionError(422, 'ai_safety_blocked'),
      CoachServiceStatus.safetyBlocked,
    );
    for (final code in <String?>[
      null,
      'AI_SAFETY_BLOCKED',
      'ai_safety_blocked ',
      'provider_safety_blocked',
    ]) {
      expect(
        coachServiceStatusForFunctionError(422, code),
        CoachServiceStatus.temporarilyUnavailable,
      );
    }
    expect(
      coachServiceStatusForFunctionError(503, 'ai_safety_blocked'),
      CoachServiceStatus.temporarilyUnavailable,
    );
    expect(
      coachServiceStatusAllowsAutomaticSpeech(CoachServiceStatus.safetyBlocked),
      isFalse,
    );
    expect(
      coachServiceStatusAllowsSameRequestRetry(
        CoachServiceStatus.safetyBlocked,
      ),
      isFalse,
    );
    expect(
      coachServiceStatusAllowsSameRequestRetry(
        CoachServiceStatus.temporarilyUnavailable,
      ),
      isTrue,
    );
  });

  test('analysis questions are not hijacked by logging navigation', () {
    const parser = LocalCoachCommandParser();
    expect(parser.parse('Analyze my weight plateau', locale: 'en'), isEmpty);
    expect(parser.parse('Review my food day', locale: 'en'), isEmpty);
    expect(
      parser.parse('Why did my workout performance drop?', locale: 'en'),
      isEmpty,
    );
    expect(parser.parse('حلل ثبات وزني هذا الأسبوع', locale: 'ar'), isEmpty);

    final weightHistory = parser.parse('Open my weight log', locale: 'en');
    expect(weightHistory, hasLength(1));
    expect(weightHistory.single.type, IntelligenceActionType.navigate);
    expect(weightHistory.single.payload['target'], 'weight_history');
    final arabicWeightHistory = parser.parse('استعرض سجل أوزاني', locale: 'ar');
    expect(arabicWeightHistory, hasLength(1));
    expect(arabicWeightHistory.single.type, IntelligenceActionType.navigate);
    expect(arabicWeightHistory.single.payload['target'], 'weight_history');
    expect(parser.parse('Log weight 82 kg', locale: 'en'), isNotEmpty);
    expect(parser.parse('I ate chicken and rice', locale: 'en'), isNotEmpty);
    expect(parser.parse('Open workouts', locale: 'en'), isNotEmpty);
  });

  test('local target-goal commands are explicit, bounded, and confirmed', () {
    const parser = LocalCoachCommandParser();

    final english = parser.parse('Set my target weight to 82 kg', locale: 'en');
    expect(english, hasLength(1));
    expect(english.single.type, IntelligenceActionType.updateGoal);
    expect(english.single.requiresConfirmation, isTrue);
    expect(english.single.payload['targetWeightKg'], 82);

    final arabic = parser.parse('اجعل هدفي ٧٨ كيلو', locale: 'ar');
    expect(arabic.single.type, IntelligenceActionType.updateGoal);
    expect(arabic.single.payload['targetWeightKg'], 78);

    expect(
      parser.parse('Set my target weight to 19 kg', locale: 'en'),
      isEmpty,
    );
    expect(
      parser.parse('Set my target weight to 501 kg', locale: 'en'),
      isEmpty,
    );
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

  test(
    'model goal tool accepts the exact targetWeightKg argument contract',
    () async {
      final result =
          await ModelBackedLocalCoachApi(
            gateway: const _GoalActionGateway(),
            context: CoachContextSnapshot.empty(),
          ).understand(
            const LocalCoachRequest(
              // Keep this follow-up free of a number so the model-selected action,
              // rather than the deterministic command parser, is under test.
              text: 'Yes, apply the goal we just discussed',
              locale: 'en',
            ),
          );

      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, IntelligenceActionType.updateGoal);
      expect(result.actions.single.payload, {'targetWeightKg': 79});
      expect(result.actions.single.requiresConfirmation, isTrue);
    },
  );

  test(
    'exhausted AI tokens expose Boost without requiring a membership',
    () async {
      final reply =
          await const IntelligenceCenterEngine(
            localApi: _CreditsRequiredApi(),
          ).answer(
            question: 'Build my plan from my recent data',
            arabic: false,
            localeCode: 'en',
            coachContext: CoachContextSnapshot.empty(),
          );

      expect(reply.serviceStatus, CoachServiceStatus.creditsRequired);
      expect(reply.actions.map((action) => action.type), [
        IntelligenceActionType.buyAiBoost,
      ]);
      expect(reply.message.text, contains('No message was charged'));
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

class _GoalActionGateway implements LocalModelGateway {
  const _GoalActionGateway();

  @override
  Future<LocalModelResult> answer({
    required String question,
    required String locale,
    required CoachContextSnapshot context,
    bool languageDetected = false,
    List<CoachConversationTurn> conversation = const [],
  }) async => const LocalModelResult.answer(
    LocalModelAnswer(
      text: 'I can update that after your in-app confirmation.',
      action: {
        'name': 'update_goal',
        'arguments': {'targetWeightKg': 79},
      },
      processedOnDevice: false,
    ),
  );
}

class _CreditsRequiredApi implements LocalCoachApi {
  const _CreditsRequiredApi();

  @override
  Future<LocalCoachResult> understand(LocalCoachRequest request) async =>
      const LocalCoachResult(
        actions: [],
        processedOnDevice: false,
        serviceStatus: CoachServiceStatus.creditsRequired,
        runtime: CoachAnswerRuntime.localFallback,
        diagnosticCode: 'ai_usage_exhausted',
      );
}
