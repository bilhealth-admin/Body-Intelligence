import '../../ai_platform/domain/ai_coach_response.dart';
import '../domain/coach_context_snapshot.dart';
import '../domain/intelligence_action.dart';
import '../domain/intelligence_message.dart';
import '../ai_coach_safety_copy.dart';
import '../intelligence_locale_copy.dart';
import 'external_knowledge_provider.dart';
import 'intelligence_health_context_provider.dart';
import 'coach_intent_normalizer.dart';
import 'coach_language_resolver.dart';
import 'coach_speech_policy.dart';
import 'local_coach_api.dart';
import 'local_model_gateway.dart';

part 'intelligence_center_reply.dart';
part 'intelligence_scope_classifiers.dart';

class IntelligenceCenterEngine {
  const IntelligenceCenterEngine({
    this.externalProvider = const DisabledExternalKnowledgeProvider(),
    this.localApi = const DeterministicLocalCoachApi(),
  });
  final ExternalKnowledgeProvider externalProvider;
  final LocalCoachApi localApi;

  bool canAnswerWithoutPersonalContext(String question) {
    final normalized = question.trim().toLowerCase();
    return normalized.isEmpty ||
        _isGreeting(normalized) ||
        _looksUrgent(normalized) ||
        _looksLikeDiagnosis(normalized) ||
        question.length > 500 ||
        const CoachSpeechPolicy().isSleepQuestion(question);
  }

  bool isGreetingQuestion(String question) =>
      _isGreeting(question.trim().toLowerCase());

  IntelligenceCenterReply fromCoach(
    AiCoachResponse response, {
    required bool arabic,
    String? localeCode,
  }) {
    final locale = localeCode ?? _legacyLocale(arabic);
    return IntelligenceCenterReply(
      message: IntelligenceMessage(
        id: 'coach-${response.generatedAt.microsecondsSinceEpoch}',
        role: IntelligenceMessageRole.bil,
        kind: IntelligenceMessageKind.coach,
        text: response.message,
        createdAt: response.generatedAt,
        evidence: response.evidenceIds,
        confidence: response.canProceed ? .8 : .35,
        actionId: response.actionId,
      ),
      actions: response.actionId == null
          ? const []
          : [
              IntelligenceAction(
                id: response.actionId!,
                type: IntelligenceActionType.openDailyLog,
                label: intelligenceTextFor(
                  locale,
                  'Take action',
                  'نفّذ الخطوة',
                ),
                requiresConfirmation: true,
              ),
            ],
      usedExternalKnowledge: false,
      spokenText: null,
    );
  }

  Future<IntelligenceCenterReply> answer({
    required String question,
    required bool arabic,
    String? localeCode,
    String? detectedLanguageTag,
    IntelligenceHealthContext? healthContext,
    CoachContextSnapshot? coachContext,
    CoachInputChannel inputChannel = CoachInputChannel.text,
    List<CoachConversationTurn> conversation = const [],
  }) async {
    final locale = localeCode ?? _legacyLocale(arabic);
    final coachLanguage = const CoachLanguageResolver().resolve(
      input: question,
      uiLocale: locale,
      detectedLanguageTag: detectedLanguageTag,
    );
    // Conversation copy follows the language of the user's message, not the
    // interface locale. This keeps (for example) Arabic questions and safety
    // replies Arabic while the surrounding app is displayed in Chinese.
    final replyLocale = coachLanguage.languageTag;
    String tr(String en, String ar) => intelligenceTextFor(replyLocale, en, ar);
    final normalized = question.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _plain(tr('Enter your question first.', 'اكتب سؤالك أولًا.'));
    }
    if (_looksUrgent(normalized)) {
      return _plain(
        tr(
          'These symptoms may be urgent. Do not rely on BIL for diagnosis or delay care: contact local emergency services or seek immediate medical help now. If you are alone, contact someone nearby.',
          'قد تكون هذه الأعراض طارئة. لا تعتمد على BIL للتشخيص أو تؤخر الرعاية: اتصل بخدمات الطوارئ المحلية أو اطلب مساعدة طبية فورية الآن. إذا كنت وحدك، فتواصل مع شخص قريب منك.',
        ),
      );
    }
    if (_looksLikeDiagnosis(normalized)) {
      return _reply(
        tr(
          'I cannot diagnose a medical condition. I can help organize symptoms and questions for a clinician and explain general information without presenting it as a diagnosis.',
          'لا أستطيع تشخيص حالة طبية. أستطيع مساعدتك في تنظيم الأعراض والأسئلة لمناقشتها مع مختص وشرح معلومات عامة من دون تقديمها كتشخيص.',
        ),
        kind: IntelligenceMessageKind.safety,
        evidence: const ['medical-safety-boundary'],
        confidence: 1,
        reason: tr(
          'Diagnosis requires qualified clinical evaluation.',
          'التشخيص يحتاج إلى تقييم سريري مؤهل.',
        ),
      );
    }
    if (question.length > 500) {
      return _plain(
        tr(
          'Please keep your health question under 500 characters so I can answer precisely.',
          'اختصر سؤالك الصحي إلى 500 حرف أو أقل حتى أجيبك بدقة.',
        ),
      );
    }

    final sleep = _answerSleepDuration(question, replyLocale);
    if (sleep != null) return sleep;
    final weight = _answerRecordedWeight(question, replyLocale, coachContext);
    if (weight != null) return weight;
    final target = _answerDailyTarget(normalized, replyLocale, coachContext);
    if (target != null) return target;
    // A short voice greeting is fully local. This prevents a transient cloud
    // outage from turning a simple spoken "كيفك"/"good evening" into a 30s
    // service error while leaving typed greetings on the consented model path.
    final local =
        inputChannel == CoachInputChannel.voice && _isGreeting(normalized)
        ? const LocalCoachResult(actions: [], processedOnDevice: true)
        : await localApi.understand(
            LocalCoachRequest(
              text: question,
              locale: coachLanguage.languageTag,
              languageDetected: coachLanguage.detected,
              channel: inputChannel,
              conversation: conversation,
            ),
          );
    if (local.serviceStatus != CoachServiceStatus.ready) {
      if (local.serviceStatus != CoachServiceStatus.safetyBlocked &&
          _isGreeting(normalized)) {
        return _reply(
          tr(
            'I am ready. Ask about your weight, food, progress, or request a plan and I will explain what is needed before building it.',
            'أنا جاهز معك. اسألني عن وزنك أو أكلك أو تقدمك، أو اطلب خطة وسأوضح ما أحتاجه قبل بنائها.',
          ),
          serviceStatus: local.serviceStatus,
          runtime: CoachAnswerRuntime.localFallback,
        );
      }
      return _serviceStatusReply(replyLocale, local.serviceStatus);
    }
    // A model answer may include an action. Preserve the answer and its
    // provenance; an action must not replace it with local-command copy. The
    // service-status gate above ensures rejected provider payloads can never
    // leak an answer, speech, or action into the conversation.
    final hasAnswer = local.answer?.trim().isNotEmpty == true;
    if (local.actions.isNotEmpty && !hasAnswer) {
      return _reply(
        tr(
          'I understood your request locally. Review the action below; I will not write data or perform a sensitive action without your confirmation.',
          'فهمت طلبك محليًا. راجع الإجراء أدناه؛ لن أكتب بيانات أو أنفذ إجراءً حساسًا من دون تأكيدك.',
        ),
        kind: IntelligenceMessageKind.action,
        evidence: const ['local-command-engine'],
        confidence: .95,
        actions: local.actions,
      );
    }
    if (hasAnswer) {
      return _reply(
        local.answer!.trim(),
        kind: local.actions.isEmpty
            ? IntelligenceMessageKind.freeQuestion
            : IntelligenceMessageKind.action,
        evidence: local.evidence.isEmpty
            ? const ['BIL user context']
            : local.evidence,
        confidence: local.confidence ?? .75,
        reason: local.reason,
        missingData: local.missingData,
        spokenText: local.spokenAnswer,
        serviceStatus: local.serviceStatus,
        runtime: local.runtime,
        responseId: local.responseId,
        actions: local.actions,
      );
    }
    if (_isGreeting(normalized)) {
      return _plain(
        tr(
          'I am ready. Ask about your weight, food, progress, or request a plan and I will explain what is needed before building it.',
          'أنا جاهز معك. اسألني عن وزنك أو أكلك أو تقدمك، أو اطلب خطة وسأوضح ما أحتاجه قبل بنائها.',
        ),
      );
    }
    if (!_isAllowedScope(normalized)) {
      return _plain(
        tr(
          'I am limited to your health, body data, and BIL. Ask about weight, nutrition, activity, sleep, progress, your plan, or how to use the app.',
          'أنا مخصص لصحتك وبيانات جسمك واستخدام BIL. اسألني عن الوزن أو التغذية أو النشاط أو النوم أو التقدم أو خطتك أو طريقة استخدام التطبيق.',
        ),
      );
    }
    if (_has(normalized, const ['hydration', 'hydrate', 'dehydration'])) {
      return _plain(
        tr(
          'Sip water regularly across the day and use thirst plus pale-yellow urine as practical hydration cues. Needs vary with heat, exercise, pregnancy, medicines, and health conditions.',
          'اشرب الماء بانتظام خلال اليوم، واستخدم العطش ولون البول الأصفر الفاتح كإشارتين عمليتين للترطيب. تختلف الاحتياجات مع الحرارة والتمرين والحمل والأدوية والحالات الصحية.',
        ),
      );
    }
    if (_isPlanRequest(normalized)) {
      return _planReply(replyLocale, healthContext);
    }
    if (_looksLikeLogging(normalized)) {
      return _reply(
        tr(
          'Understood. I can turn that into a log, but I will not add anything without your confirmation.',
          'فهمت. يمكنني تحويل كلامك إلى سجل، لكن لن أضيف شيئًا قبل موافقتك.',
        ),
        kind: IntelligenceMessageKind.action,
        memoryCandidate: question.trim(),
        actions: [
          IntelligenceAction(
            id: 'open-daily-log',
            type: IntelligenceActionType.openDailyLog,
            label: tr('Open daily log', 'افتح تسجيل اليوم'),
            requiresConfirmation: true,
          ),
          IntelligenceAction(
            id: 'save-memory',
            type: IntelligenceActionType.saveMemory,
            label: tr('Remember this about me', 'احفظ هذه المعلومة عني'),
            requiresConfirmation: true,
            payload: {'text': question.trim()},
          ),
        ],
      );
    }
    if (healthContext != null && _looksPersonal(normalized)) {
      final hasAction = healthContext.actionTitle?.trim().isNotEmpty == true;
      return _reply(
        hasAction
            ? tr(
                'Best reading available now: {action}. I will not apply it until you approve.',
                'أفضل قراءة متاحة الآن: {action}. لن أعتمدها كإجراء إلا بعد موافقتك.',
              ).replaceAll('{action}', healthContext.actionTitle!)
            : healthContext.primaryMessage,
        evidence: const ['Body Twin', 'Truth Engine'],
        confidence: healthContext.confidence,
        reason: healthContext.explanation.isEmpty
            ? tr(
                'Body Twin data was checked by Truth Engine before this answer.',
                'راجعت بيانات توأم الجسم عبر محرك الحقيقة قبل هذه الإجابة.',
              )
            : healthContext.explanation.first,
        missingData: healthContext.missingData,
        actions: healthContext.actionId == null
            ? const []
            : [
                IntelligenceAction(
                  id: healthContext.actionId!,
                  type: IntelligenceActionType.openDailyLog,
                  label: tr('Review suggested action', 'راجع الإجراء المقترح'),
                  requiresConfirmation: true,
                ),
              ],
      );
    }
    final external = await externalProvider.answerGeneralQuestion(
      question: question,
      locale: replyLocale,
    );
    if (external?.trim().isNotEmpty == true) {
      return _reply(external!.trim(), usedExternalKnowledge: true);
    }
    return _plain(
      tr(
        'The personalized AI Coach is temporarily unavailable. No message was charged; try again shortly.',
        'المدرب الذكي المخصص غير متاح مؤقتًا. لم يتم احتساب أي رسالة؛ أعد المحاولة بعد قليل.',
      ),
    );
  }

  IntelligenceCenterReply _planReply(
    String locale,
    IntelligenceHealthContext? context,
  ) {
    String tr(String en, String ar) => intelligenceTextFor(locale, en, ar);
    final ready = context != null;
    return _reply(
      ready
          ? tr(
                  'Reviewable plan draft: {action}. {reason} I will not change your plan before your approval.',
                  'مسودة خطة قابلة للمراجعة: {action}. {reason} لن أغيّر خطتك قبل اعتمادك.',
                )
                .replaceAll(
                  '{action}',
                  context.actionTitle ?? context.primaryMessage,
                )
                .replaceAll('{reason}', context.actionReason ?? '')
          : tr(
              'There is not enough local context to build a personal plan now. I will not present a generic plan as personal.',
              'لا توجد بيانات محلية كافية لبناء خطة شخصية الآن. لن أقدم خطة عامة وأدّعي أنها شخصية.',
            ),
      kind: IntelligenceMessageKind.action,
      evidence: context?.evidence ?? const [],
      confidence: context?.confidence,
      reason: context == null || context.explanation.isEmpty
          ? null
          : context.explanation.first,
      missingData: context?.missingData ?? const [],
      actions: [
        IntelligenceAction(
          id: 'open-plan',
          type: IntelligenceActionType.openPlan,
          label: tr('Open plan settings', 'افتح إعدادات الخطة'),
          requiresConfirmation: false,
        ),
      ],
    );
  }

  IntelligenceCenterReply? _answerDailyTarget(
    String question,
    String locale,
    CoachContextSnapshot? context,
  ) {
    // Only a direct target lookup is a local shortcut. Mentioning protein in
    // a meal-choice, remaining-intake or comparison question is not a request
    // to repeat the full daily target (including the daily brief's CTA).
    if (!_isDailyTargetLookup(question)) return null;
    final raw = context?.computedHealth['dailyTargets'];
    if (raw is! Map) return null;
    final targets = Map<String, Object?>.from(raw);
    final rawSources = context?.computedHealth['dailyTargetSources'];
    final sources = rawSources is Map
        ? Map<String, Object?>.from(rawSources)
        : const <String, Object?>{};
    String tr(String en, String ar) => intelligenceTextFor(locale, en, ar);
    if ((question.contains('protein') || question.contains('بروتين')) &&
        targets['proteinG'] is num) {
      final target = (targets['proteinG']! as num).toDouble();
      if (!target.isFinite || target <= 0) return null;
      final value = target.round();
      final source = sources['proteinG']?.toString();
      final sourceCopy = switch (source) {
        'saved_gram_goal' => tr(
          'It comes from the explicit protein goal saved in Nutrition Goals.',
          'مصدره هدف البروتين الصريح المحفوظ في أهداف التغذية.',
        ),
        'scheduled_gram_goal' => tr(
          "It comes from today's scheduled protein goal in grams.",
          'مصدره هدف بروتين اليوم المجدول بالغرام.',
        ),
        'saved_percentage_goal' => tr(
          'It is derived from your saved calorie and protein-percentage goals.',
          'وهو مشتق من هدفي السعرات ونسبة البروتين المحفوظين.',
        ),
        'saved_plan_override' || 'saved_plan_recommendation' => tr(
          'It comes from the target saved in your BIL plan.',
          'مصدره الهدف المحفوظ في خطتك داخل BIL.',
        ),
        'body_profile_calculation' => tr(
          'It comes from the current BIL body-profile calculation.',
          'مصدره حساب BIL الحالي المبني على ملف جسمك.',
        ),
        _ => tr(
          'It comes from your current BIL nutrition-target context.',
          'مصدره سياق أهداف التغذية الحالي داخل BIL.',
        ),
      };
      return _reply(
        tr(
              'Your current daily protein target is {value} g. {source}',
              'هدفك اليومي الحالي هو {value} غرامًا من البروتين. {source}',
            )
            .replaceAll('{value}', value.toString())
            .replaceAll('{source}', sourceCopy),
        evidence: ['dailyTargets.proteinG', ?source],
        confidence: 1,
      );
    }
    if ((question.contains('calorie') ||
            question.contains('kcal') ||
            question.contains('سعرات')) &&
        targets['caloriesKcal'] is num) {
      final value = (targets['caloriesKcal']! as num).round();
      return _plain(
        tr(
          'Your current daily target is {value} kcal. This is the target saved in your BIL plan, not a generic estimate.',
          'هدفك اليومي الحالي هو {value} سعرة حرارية. هذا هو الهدف المحفوظ في خطتك وليس تقديرًا عامًا.',
        ).replaceAll('{value}', value.toString()),
      );
    }
    return null;
  }

  bool _isDailyTargetLookup(String question) {
    final text = question
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll(RegExp(r'[?؟.!،]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return const {
          'protein',
          'calories',
          'calorie',
          'kcal',
          'بروتين',
          'البروتين',
          'سعرات',
          'السعرات',
          'how much protein do i need',
          'how many calories do i need',
          'كم احتاج بروتين',
          'كم احتاج من البروتين',
          'كم احتاج سعرات',
          'كم احتاج من السعرات',
        }.contains(text) ||
        RegExp(
          r"^(?:(?:what is|what's|show me) )?(?:(?:my|the) )?(?:(?:current|saved|daily) )*(?:protein|calorie|calories|kcal) (?:target|goal)(?: today| per day)?$",
        ).hasMatch(text) ||
        RegExp(
          r'^(?:(?:ما هو|ما|كم|اعرض) )?(?:هدف|هدفي|احتياجي)(?: اليومي)?(?: من)? (?:البروتين|بروتين|السعرات|السعرات الحرارية)(?: اليومي| اليوم)?$',
        ).hasMatch(text);
  }

  IntelligenceCenterReply? _answerRecordedWeight(
    String question,
    String locale,
    CoachContextSnapshot? context,
  ) {
    if (!const CoachSpeechPolicy().isWeightLookup(question)) return null;
    String tr(String en, String ar) => intelligenceTextFor(locale, en, ar);
    final latest = context?.weights.isNotEmpty == true
        ? context!.weights.first.kg
        : (context?.profile['currentWeightKg'] as num?)?.toDouble();
    if (latest == null || !latest.isFinite || latest <= 0) {
      return _reply(
        tr(
          'I do not have a recorded weight yet. Add a weight check-in and I can use it in future answers.',
          'لا يوجد لدي وزن مسجل بعد. أضف قياس وزن وسأستخدمه في الإجابات القادمة.',
        ),
        evidence: const ['local weight record'],
        confidence: 1,
        missingData: const ['currentWeightKg'],
      );
    }
    final value = latest.toStringAsFixed(
      latest == latest.roundToDouble() ? 0 : 1,
    );
    return _reply(
      tr(
        'Your latest recorded weight is {weight} kg.',
        'آخر وزن مسجل لديك هو {weight} كغ.',
      ).replaceAll('{weight}', value),
      evidence: const ['local latest weight'],
      confidence: 1,
      reason: tr(
        'This value comes from your latest verified local weight record.',
        'هذه القيمة مأخوذة من أحدث سجل وزن محلي موثّق لديك.',
      ),
    );
  }

  IntelligenceCenterReply? _answerSleepDuration(
    String question,
    String locale,
  ) {
    if (!const CoachSpeechPolicy().isSleepQuestion(question)) return null;
    final text = intelligenceTextFor(
      locale,
      'Most adults need 7–9 hours of sleep each night.',
      'يحتاج معظم البالغين إلى 7–9 ساعات من النوم كل ليلة.',
    );
    return _reply(
      text,
      evidence: const ['general adult sleep-duration guidance'],
      confidence: .85,
      spokenText: text,
    );
  }

  IntelligenceCenterReply _plain(String text) => _reply(text);
  IntelligenceCenterReply _reply(
    String text, {
    IntelligenceMessageKind kind = IntelligenceMessageKind.freeQuestion,
    List<String> evidence = const [],
    double? confidence,
    String? reason,
    List<String> missingData = const [],
    String? memoryCandidate,
    List<IntelligenceAction> actions = const [],
    bool usedExternalKnowledge = false,
    String? spokenText,
    CoachServiceStatus serviceStatus = CoachServiceStatus.ready,
    CoachAnswerRuntime runtime = CoachAnswerRuntime.onDevice,
    String? responseId,
  }) => IntelligenceCenterReply(
    message: IntelligenceMessage(
      id: responseId ?? 'reply-${DateTime.now().microsecondsSinceEpoch}',
      role: IntelligenceMessageRole.bil,
      kind: kind,
      text: text,
      createdAt: DateTime.now(),
      evidence: evidence,
      confidence: confidence,
      reason: reason,
      missingData: missingData,
      memoryCandidate: memoryCandidate,
    ),
    actions: actions,
    usedExternalKnowledge: usedExternalKnowledge,
    spokenText: spokenText,
    serviceStatus: serviceStatus,
    runtime: runtime,
  );

  IntelligenceCenterReply _serviceStatusReply(
    String locale,
    CoachServiceStatus status,
  ) {
    String tr(String en, String ar) => intelligenceTextFor(locale, en, ar);
    final text = switch (status) {
      CoachServiceStatus.signedOut => tr(
        'Sign in to use the personalized AI Coach. I did not send any health data.',
        'سجّل الدخول لاستخدام المدرب الذكي المخصص. لم أرسل أي بيانات صحية.',
      ),
      CoachServiceStatus.consentRequired => tr(
        'Personalized AI is off. Enable Remote AI consent in AI Coach settings before sending this question.',
        'الذكاء الاصطناعي المخصص متوقف. فعّل موافقة الذكاء الاصطناعي البعيد من إعدادات المدرب قبل إرسال هذا السؤال.',
      ),
      CoachServiceStatus.quotaExhausted => tr(
        'Your AI Coach allowance is exhausted for this period. No message was charged and I will not pretend this is a Gemini answer.',
        'استهلكت حصة المدرب الذكي لهذه الفترة. لم تُحتسب هذه الرسالة، ولن أدّعي أن الرد صادر من Gemini.',
      ),
      CoachServiceStatus.creditsRequired => tr(
        'Your available AI tokens are exhausted. No message was charged. Add AI Boost tokens to continue.',
        'نفدت توكنات AI المتاحة. لم تُحتسب الرسالة. أضف توكنات AI Boost للمتابعة.',
      ),
      CoachServiceStatus.safetyBlocked => AiCoachSafetyCopy.resolve(locale),
      CoachServiceStatus.temporarilyUnavailable => tr(
        'The personalized AI Coach is temporarily unavailable. No message was charged; try again shortly.',
        'المدرب الذكي المخصص غير متاح مؤقتًا. لم تُحتسب الرسالة؛ حاول مجددًا بعد قليل.',
      ),
      CoachServiceStatus.ready => '',
    };
    return _reply(
      text,
      kind: IntelligenceMessageKind.safety,
      confidence: 1,
      evidence: const ['AI Coach service status'],
      actions: status == CoachServiceStatus.creditsRequired
          ? [
              IntelligenceAction(
                id: 'buy-ai-boost',
                type: IntelligenceActionType.buyAiBoost,
                label: tr('Get AI Boost', 'احصل على AI Boost'),
                requiresConfirmation: false,
              ),
            ]
          : const [],
      serviceStatus: status,
      runtime: CoachAnswerRuntime.localFallback,
    );
  }

  String _legacyLocale(bool arabic) => switch (arabic) {
    true => 'ar',
    false => 'en',
  };
}
