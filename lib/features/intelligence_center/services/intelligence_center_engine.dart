import '../../ai_platform/domain/ai_coach_response.dart';
import '../domain/coach_context_snapshot.dart';
import '../domain/intelligence_action.dart';
import '../domain/intelligence_message.dart';
import '../intelligence_locale_copy.dart';
import 'external_knowledge_provider.dart';
import 'intelligence_health_context_provider.dart';
import 'coach_intent_normalizer.dart';
import 'coach_language_resolver.dart';
import 'local_coach_api.dart';

class IntelligenceCenterReply {
  const IntelligenceCenterReply({
    required this.message,
    required this.actions,
    required this.usedExternalKnowledge,
    this.spokenText,
  });
  final IntelligenceMessage message;
  final List<IntelligenceAction> actions;
  final bool usedExternalKnowledge;
  final String? spokenText;
}

/// Safety-first, presentation-neutral orchestration for AI Coach.
class IntelligenceCenterEngine {
  const IntelligenceCenterEngine({
    this.externalProvider = const DisabledExternalKnowledgeProvider(),
    this.localApi = const DeterministicLocalCoachApi(),
  });
  final ExternalKnowledgeProvider externalProvider;
  final LocalCoachApi localApi;

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
    IntelligenceHealthContext? healthContext,
    CoachContextSnapshot? coachContext,
    CoachInputChannel inputChannel = CoachInputChannel.text,
  }) async {
    final locale = localeCode ?? _legacyLocale(arabic);
    final coachLanguage = const CoachLanguageResolver().resolve(
      input: question,
      uiLocale: locale,
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
    if (_isGreeting(normalized)) {
      return _plain(
        tr(
          'I am ready. Ask about your weight, food, progress, or request a plan and I will explain what is needed before building it.',
          'أنا جاهز معك. اسألني عن وزنك أو أكلك أو تقدمك، أو اطلب خطة وسأوضح ما أحتاجه قبل بنائها.',
        ),
      );
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

    final target = _answerDailyTarget(normalized, replyLocale, coachContext);
    if (target != null) return target;
    final local = await localApi.understand(
      LocalCoachRequest(
        text: question,
        locale: coachLanguage.languageTag,
        channel: inputChannel,
      ),
    );
    if (local.actions.isNotEmpty) {
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
    if (local.answer?.trim().isNotEmpty == true) {
      return _reply(
        local.answer!.trim(),
        evidence: const ['local-model', 'BIL user context'],
        confidence: .75,
        spokenText: local.spokenAnswer,
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
                'Best reading available now: ${healthContext.actionTitle}. I will not apply it until you approve.',
                'أفضل قراءة متاحة الآن: ${healthContext.actionTitle}. لن أعتمدها كإجراء إلا بعد موافقتك.',
              )
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
        'I understand the question, but general conversation and full body-context integration are not enabled yet. I will not invent an answer.',
        'أفهم سؤالك، لكن المحادثة العامة وربط سياق جسمك الكامل غير مفعّلين بعد. لن أختلق جوابًا.',
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
              'Reviewable plan draft: ${context.actionTitle ?? context.primaryMessage}. ${context.actionReason ?? ''} I will not change your plan before your approval.',
              'مسودة خطة قابلة للمراجعة: ${context.actionTitle ?? context.primaryMessage}. ${context.actionReason ?? ''} لن أغيّر خطتك قبل اعتمادك.',
            )
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
    final raw = context?.computedHealth['dailyTargets'];
    if (raw is! Map) return null;
    final targets = Map<String, Object?>.from(raw);
    String tr(String en, String ar) => intelligenceTextFor(locale, en, ar);
    if ((question.contains('protein') || question.contains('بروتين')) &&
        targets['proteinG'] is num) {
      final value = (targets['proteinG']! as num).round();
      return _plain(
        tr(
          'Your current daily protein target is $value g. This is the target saved in your BIL plan.',
          'هدفك اليومي الحالي هو $value غرامًا من البروتين. هذا هو الهدف المحفوظ في خطتك داخل BIL.',
        ),
      );
    }
    if ((question.contains('calorie') ||
            question.contains('kcal') ||
            question.contains('سعرات')) &&
        targets['caloriesKcal'] is num) {
      final value = (targets['caloriesKcal']! as num).round();
      return _plain(
        tr(
          'Your current daily target is $value kcal. This is the target saved in your BIL plan, not a generic estimate.',
          'هدفك اليومي الحالي هو $value سعرة حرارية. هذا هو الهدف المحفوظ في خطتك وليس تقديرًا عامًا.',
        ),
      );
    }
    return null;
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
  }) => IntelligenceCenterReply(
    message: IntelligenceMessage(
      id: 'reply-${DateTime.now().microsecondsSinceEpoch}',
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
  );

  bool _has(String value, List<String> markers) => markers.any(value.contains);
  bool _isGreeting(String v) => _has(v, const [
    'مرحبا',
    'مرحبًا',
    'أهلا',
    'أهلًا',
    'السلام عليكم',
    'صباح الخير',
    'مساء الخير',
    'hi',
    'hello',
    'hey',
    'how are you',
  ]);
  bool _isPlanRequest(String v) => _has(v, const [
    'خطة',
    'برنامج',
    'رتب لي',
    'اعمل لي',
    'أعمل لي',
    'plan',
    'program',
  ]);
  bool _looksLikeLogging(String v) => _has(v, const [
    'أكلت',
    'شربت',
    'تمرنت',
    'وزني',
    'i ate',
    'i drank',
    'i trained',
    'my weight',
  ]);
  bool _looksPersonal(String v) => _has(v, const [
    'جسمي',
    'وزني',
    'أكلي',
    'وجباتي',
    'بروتين',
    'سعرات',
    'تقدمي',
    'الماء',
    'ثبات',
    'هدف',
    'بياناتي',
    'لماذا',
    'my body',
    'my weight',
    'my food',
    'protein',
    'calories',
    'progress',
    'water',
    'hydration',
    'hydrate',
    'dehydration',
    'plateau',
    'goal',
    'my data',
    'why',
  ]);
  bool _looksLikeDiagnosis(String v) => _has(v, const [
    'شخصني',
    'تشخيص',
    'هل عندي',
    'هل مصاب',
    'مرض',
    'دواء',
    'جرعة',
    'diagnose',
    'diagnosis',
    'do i have',
    'disease',
    'medication',
    'dose',
  ]);
  bool _looksUrgent(String v) => _has(v, const [
    'ألم صدر',
    'لا أستطيع التنفس',
    'صعوبة تنفس',
    'إغماء',
    'نزيف شديد',
    'أفكر بالانتحار',
    'chest pain',
    "can't breathe",
    'difficulty breathing',
    'fainted',
    'severe bleeding',
    'suicide',
  ]);
  bool _isAllowedScope(String v) => _has(v, const [
    'صحة',
    'جسم',
    'وزن',
    'أكل',
    'غذاء',
    'وجبة',
    'بروتين',
    'سعرات',
    'ماء',
    'نوم',
    'نشاط',
    'رياضة',
    'تمرين',
    'خطوات',
    'دهون',
    'عضلات',
    'قياس',
    'هدف',
    'تقدم',
    'خطة',
    'دواء',
    'مرض',
    'أعراض',
    'ألم',
    'bil',
    'توأم',
    'البرنامج',
    'التطبيق',
    'التسجيل',
    'coach',
    'health',
    'body',
    'weight',
    'food',
    'meal',
    'nutrition',
    'protein',
    'calories',
    'water',
    'hydration',
    'hydrate',
    'dehydration',
    'sleep',
    'activity',
    'exercise',
    'steps',
    'fat',
    'muscle',
    'measurement',
    'goal',
    'progress',
    'plan',
    'medicine',
    'symptom',
    'pain',
    'app',
    'log',
  ]);

  String _legacyLocale(bool arabic) => switch (arabic) {
    true => 'ar',
    false => 'en',
  };
}
