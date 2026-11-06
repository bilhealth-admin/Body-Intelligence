import 'dart:convert';

import '../domain/coach_context_snapshot.dart';
import 'coach_cloud_payload_sanitizer.dart';
import 'local_model_gateway.dart';

part 'coach_cloud_context_projection_helpers.dart';
part 'coach_cloud_smart_plan_projection.dart';

/// The only personal-data groups the mobile client may project into one
/// remote Coach request. A future context field is excluded until it is
/// deliberately assigned to one of these groups below.
enum CoachCloudContextCategory {
  sleepAndHabits('sleep_habits'),
  weightMeasurementsAndGoal('weight_measurements_goal'),
  nutritionAndWater('nutrition_water'),
  trainingAndActivity('training_activity');

  const CoachCloudContextCategory(this.wireName);

  final String wireName;
}

class CoachCloudContextProjection {
  const CoachCloudContextProjection({
    required this.context,
    required this.disclosure,
  });

  final Map<String, Object?> context;
  final Map<String, Object?> disclosure;
}

abstract interface class CoachCloudContextProjector {
  CoachCloudContextProjection project({
    required String question,
    required CoachContextSnapshot context,
    required List<CoachConversationTurn> conversation,
  });
}

class QuestionScopedCoachCloudContextProjector
    implements CoachCloudContextProjector {
  const QuestionScopedCoachCloudContextProjector();

  @override
  CoachCloudContextProjection project({
    required String question,
    required CoachContextSnapshot context,
    required List<CoachConversationTurn> conversation,
  }) => projectCoachCloudContext(
    question: question,
    context: context,
    conversation: conversation,
  );
}

/// Accept only the current, explicit consent receipt used by the release.
/// The Edge Function repeats this check as defense in depth.
bool isCurrentRemoteAiConsentGranted(Object? raw) =>
    raw is Map && raw['granted'] == true && raw['policy_version'] == '3';

/// Returns true only for an HTTP(S) endpoint bound to this device's exact
/// loopback host. LAN hosts, public hosts, lookalikes, and other schemes are
/// never treated as an on-device model, regardless of bearer credentials.
bool isLoopbackLocalModelEndpoint(String endpoint) {
  final uri = Uri.tryParse(endpoint);
  return uri != null &&
      {'http', 'https'}.contains(uri.scheme) &&
      {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
}

/// Classifies only data categories explicitly implicated by the latest
/// question. If the latest turn is a short follow-up, the immediately prior
/// user turn may supply its missing topic; assistant text is never used.
Set<CoachCloudContextCategory> coachCloudContextCategoriesForQuestion({
  required String question,
  List<CoachConversationTurn> conversation = const [],
}) {
  return _coachCloudCategoriesInText(
    _coachCloudScopeText(question, conversation),
  );
}

String _coachCloudScopeText(
  String question,
  List<CoachConversationTurn> conversation,
) {
  if (_coachCloudCategoriesInText(question).isNotEmpty ||
      !_isCoachCategoryFollowUp(question)) {
    return question;
  }
  for (final turn in conversation.reversed) {
    if (turn.role != 'user') continue;
    final prior = turn.content.trim();
    if (prior.isEmpty || prior == question.trim()) continue;
    final priorCategories = _coachCloudCategoriesInText(prior);
    // Short slot answers such as "83", "today", or "yes" do not carry a
    // category by themselves. Keep walking back to the nearest explicit user
    // topic instead of dropping the task that the Coach is completing.
    if (priorCategories.isNotEmpty) return prior;
    // A fresh general question ends the old private topic. Only slot answers
    // and bounded follow-ups may be skipped when resolving a clarification.
    if (!_isCoachCategoryFollowUp(prior)) break;
  }
  return question;
}

bool _isCoachCategoryFollowUp(String source) {
  final text = source.trim().toLowerCase().replaceAll(RegExp(r'[؟?!.]+$'), '');
  if (RegExp(r'^[0-9٠-٩۰-۹]+(?:[.,٫][0-9٠-٩۰-۹]+)?$').hasMatch(text)) {
    return true;
  }
  if (const {
    'yes',
    'no',
    'ok',
    'okay',
    'today',
    'yesterday',
    'tomorrow',
    'why',
    'why is that happening',
    'why is that',
    'continue',
    'explain more',
    'نعم',
    'لا',
    'تمام',
    'موافق',
    'اليوم',
    'امس',
    'أمس',
    'بكرا',
    'غدا',
    'لماذا',
    'ليش',
    'كمل',
    'اكمل',
    'أكمل',
    'اشرح اكثر',
    'اشرح أكثر',
  }.contains(text)) {
    return true;
  }
  return text.length <= 80 &&
      RegExp(
        r'^(?:and\b|what about\b|how about\b|وماذا عن|ومبارح|وماذا|طيب وبالنسبة|والامس|وبكرا)',
      ).hasMatch(text);
}

bool _isCoachDayReview(String source) {
  final text = _normalizedCoachScopeText(source);
  return RegExp(
    r'^(?:please[, ]+|(?:can|could|would)\s+you\s+)?'
    r'(?:review|analyse|analyze|assess|summari[sz]e)\s+my\s+day\b|'
    r'^how\s+(?:was|is)\s+my\s+day\b|'
    r'^(?:(?:ممكن|اريد|بدي|ابي|ابغى|عايز|عاوز)\s+(?:منك\s+)?)?'
    r'(?:ت?راجع|ت?حلل|مراجع[ةه]|تحليل|قيم|لخص|شوف)\s+(?:لي\s+)?يومي|'
    r'^(?:كيف|شلون|ازاي)\s+(?:كان\s+)?يومي|'
    r'^(?:شو|شنو|ايه)\s+رايك\s+(?:ب|في\s*)يومي',
    unicode: true,
  ).hasMatch(text);
}

String _normalizedCoachScopeText(String source) => source
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064b-\u065f\u0670]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا');

Set<CoachCloudContextCategory> _coachDayReviewCategories(String source) {
  final allowed = CoachCloudContextCategory.values.toSet();
  final excluded = <CoachCloudContextCategory>{};
  // Bounded, explicit category constraints narrow the review. These are data
  // choices, not a new consent grant. The prepared-context intersection below
  // still applies. Excluding a field excludes its entire approved data group.
  final onlyPrefix = RegExp(
    r'\bonly\s+(?=(?:(?:my|the|recorded|saved)\s+|'
    r'nutrition\b|meals?\b|foods?\b|water\b|sleep\b|training\b|activity\b|'
    r'exercises?\b|workouts?\b|steps?\b|weight\b))|'
    r'(?:^|\s)(?:فقط|بس)\s+(?=(?:ال)?(?:تغذي|غذا|وجب|طعام|اكل|ماء|ميه|'
    r'نوم|وزن|تمرين|تمارين|تدريب|نشاط|خطوات))',
    unicode: true,
  );
  final onlySuffix = RegExp(
    r'\bonly\b|(?:^|\s)(?:فقط|بس)(?=\s|$)',
    unicode: true,
  );
  final exclusion = RegExp(
    r'\b(?:without|excluding|except(?: for)?|exclude|leave out|'
    r'(?:do not|don\x27t)\s+(?:include|use|send|read|consider))\s+|'
    r'(?:^|\s)(?:دون|بدون|باستثناء|عدا|من غير)\s+|'
    r'(?:^|\s)لا\s+(?:تستخدم|تشمل|تضم|ترسل|تقرا|تذكر)\s+',
    unicode: true,
  );
  final actionConstraint = RegExp(
    r'^(?:changing|logging|recording|editing|updating|saving|deleting)\b|'
    r'^(?:تغيير|تسجيل|تعديل|حفظ|حذف|زيادة|انقاص)(?:\s|$)',
    unicode: true,
  );
  final factClause = RegExp(
    r'\b(?:i|we)\s+(?:have\s+)?(?:only\s+)?(?:ate|drank|logged|recorded|slept)\b|'
    r'(?:^|\s)(?:اكلت|شربت|نمت|سجلت)(?:\s|$)',
    unicode: true,
  );
  final continuation = RegExp(
    r'\b(?:without|excluding|except|but|do not|don\x27t|and then)\b|'
    r'\band\s+(?:tell|give|suggest|recommend|explain)\b|'
    r'(?:^|\s)(?:دون|بدون|باستثناء|عدا|لكن|ثم|وقل|واشرح|واقترح|واخبر)(?:\s|$)',
    unicode: true,
  );
  Set<CoachCloudContextCategory> categoriesIn(String text) =>
      _coachCloudCategoriesInText(text, expandWholeContext: false);
  for (final clause in _normalizedCoachScopeText(
    source,
  ).split(RegExp(r'[.,;!?؛،\n]'))) {
    for (final match in onlyPrefix.allMatches(clause)) {
      final tail = clause.substring(match.end).split(continuation).first;
      final categories = categoriesIn(tail);
      if (categories.isNotEmpty) allowed.retainAll(categories);
    }
    for (final match in onlySuffix.allMatches(clause)) {
      final prefix = clause.substring(0, match.start).trim();
      final tail = clause.substring(match.end).trim();
      if (factClause.hasMatch(prefix) ||
          RegExp(r'^(?:if|when|whether)\b').hasMatch(tail)) {
        continue;
      }
      final categories = categoriesIn(prefix);
      if (categories.isNotEmpty) allowed.retainAll(categories);
    }
    for (final match in exclusion.allMatches(clause)) {
      final tail = clause.substring(match.end).trim();
      // "Without changing my weight" forbids a write, not a weight read.
      if (actionConstraint.hasMatch(tail)) continue;
      excluded.addAll(categoriesIn(tail.split(continuation).first));
    }
  }
  return allowed..removeAll(excluded);
}

Set<CoachCloudContextCategory> _preparedCoachCloudCategories({
  required String question,
  required CoachContextSnapshot context,
  required List<CoachConversationTurn> conversation,
}) {
  final topic = _coachCloudScopeText(question, conversation);
  final categories = _coachCloudCategoriesInText(topic);
  if (!_isCoachDayReview(topic)) return categories;
  // A whole-day review is scoped to payloads already prepared by the selected
  // focus provider. Missing groups do not grant permission or prove emptiness.
  // Use the same set for context, conversation and disclosure.
  final today = context.computedHealth['today'];
  bool todayHas(String key) => today is Map && today[key] != null;
  return categories
      .where(
        (category) => switch (category) {
          CoachCloudContextCategory.weightMeasurementsAndGoal =>
            context.weightReadStatus == CoachWeightReadStatus.verified ||
                (context.weightReadStatus != CoachWeightReadStatus.withheld &&
                    const [
                      'currentWeightKg',
                      'targetWeightKg',
                      'waistCm',
                    ].any((key) => context.profile[key] != null)),
          CoachCloudContextCategory.nutritionAndWater =>
            context.nutritionDays.isNotEmpty ||
                context.waterHistory.isNotEmpty ||
                todayHas('nutrition') ||
                context.computedHealth['dailyTargets'] != null ||
                context.profile['dietaryPreferences'] != null ||
                context.smartPlan['mealSuggestions'] != null,
          CoachCloudContextCategory.trainingAndActivity =>
            todayHas('exerciseEnergy') ||
                context.profile['exercises'] != null ||
                context.activityHistory.any(
                  (row) => row['steps'] != null || row['exercises'] != null,
                ) ||
                context.smartPlan['plannedWorkout'] != null,
          CoachCloudContextCategory.sleepAndHabits =>
            todayHas('sleep') ||
                todayHas('fasting') ||
                todayHas('bodyContext') ||
                context.bodyContextHistory.isNotEmpty ||
                context.activityHistory.any((row) => row['sleepHours'] != null),
        },
      )
      .toSet();
}

/// Keeps only prior user/assistant turns whose detected categories are a
/// subset of the latest question's scope. General questions send no history;
/// the latest question itself is appended separately by the gateway.
List<CoachConversationTurn> questionScopedCoachCloudConversation({
  required String question,
  List<CoachConversationTurn> conversation = const [],
  CoachContextSnapshot? context,
}) {
  final categories = context == null
      ? coachCloudContextCategoriesForQuestion(
          question: question,
          conversation: conversation,
        )
      : _preparedCoachCloudCategories(
          question: question,
          context: context,
          conversation: conversation,
        );
  if (categories.isEmpty) return const <CoachConversationTurn>[];
  final values = conversation
      .where(
        (turn) =>
            {'user', 'assistant'}.contains(turn.role) &&
            turn.content.trim().isNotEmpty,
      )
      .toList(growable: true);
  if (values.isNotEmpty &&
      values.last.role == 'user' &&
      values.last.content.trim() == question.trim()) {
    values.removeLast();
  }
  // Start at the latest explicit user turn in the same privacy category, then
  // retain its bounded clarification chain. This preserves "log my weight" →
  // "what value?" → "83" without leaking an older unrelated health topic.
  var chainStart = -1;
  for (var index = values.length - 1; index >= 0; index--) {
    final turn = values[index];
    if (turn.role != 'user') continue;
    final turnCategories = _coachCloudCategoriesInText(turn.content);
    if (turnCategories.isNotEmpty &&
        turnCategories.every(categories.contains)) {
      chainStart = index;
      break;
    }
  }
  if (chainStart < 0) return const <CoachConversationTurn>[];
  final retained = <CoachConversationTurn>[];
  for (final turn in values.skip(chainStart)) {
    final turnCategories = _coachCloudCategoriesInText(turn.content);
    if (turnCategories.isNotEmpty &&
        !turnCategories.every(categories.contains)) {
      break;
    }
    retained.add(turn);
  }
  return retained.length <= 8
      ? retained
      : retained.sublist(retained.length - 8);
}

Set<CoachCloudContextCategory> _coachCloudCategoriesInText(
  String source, {
  bool expandWholeContext = true,
}) {
  final text = source.toLowerCase();
  final categories = <CoachCloudContextCategory>{};
  // This explicit Overview starter asks about the selected BIL context as a
  // whole. Treating it as an unclassified general question used to discard
  // every personal category, even when the prepared snapshot contained verified
  // activity. The snapshot provider still applies each saved category choice;
  // this does not grant a withheld category or expand native permissions.
  if (expandWholeContext &&
      (text.contains('based on my selected bil context') ||
          text.contains('بناءً على سياق bil الذي اخترته') ||
          text.contains('بناء على سياق bil الذي اخترته'))) {
    return CoachCloudContextCategory.values.toSet();
  }
  // The starter's "next step" is a recommendation, not an exercise-step
  // category. Resolve the explicit day-review request before incidental words.
  // The prepared-context filter below still excludes withheld groups.
  if (expandWholeContext && _isCoachDayReview(source)) {
    return _coachDayReviewCategories(source);
  }
  bool has(RegExp pattern) => pattern.hasMatch(text);
  if (has(
    RegExp(
      r'\b(sleep|slept|bedtime|wake|waking|awake|nap|insomnia|habit|routine|fasting)\b|'
      r'sueño|dormir|sommeil|schlaf|sonno|sono|uyku|slaap|sen|tidur|ngủ|'
      r'сон|сну|خواب|نیند|नींद|ঘুম|นอน|睡眠|睡觉|睡覺|수면|'
      r'نوم|نمت|أنام|انام|استيقاظ|استيقظ|صحو|قيلولة|أرق|ارق|عادة|روتين|صيام',
      unicode: true,
    ),
  )) {
    categories.add(CoachCloudContextCategory.sleepAndHabits);
  }
  if (has(
    RegExp(
      r'\b(weights?|weigh|goal weight|target weight|waist|hip|hips|neck|chest|arm|thigh|bmi|measurements?|body fat|kilograms?|kgs?)\b|'
      // Age already belongs to this approved profile category. Recognize an
      // explicit question about the member's age, not generic mentions of age.
      r'\b(my age|how old am i)\b|(?:^|[\s،؟?!:])عمري(?:$|[\s،؟?!:.])|'
      r'peso|poids|gewicht|waga|ağırlık|berat|cân nặng|вес|вага|وزن|वज़न|ওজন|น้ำหนัก|体重|體重|체중|'
      r'هدف الوزن|وزني المستهدف|الوزن المستهدف|اوزاني|أوزاني|اوزان|أوزان|نزولي بالوزن|سجل وزني|خصر|ورك|أرداف|ارداف|رقبة|صدر|ذراع|فخذ|قياس|كتلة الجسم|كيلو',
      unicode: true,
    ),
  )) {
    categories.add(CoachCloudContextCategory.weightMeasurementsAndGoal);
  }
  if (has(
    RegExp(
      r'\b(nutrition|meals?|foods?|eat|ate|diet|calories?|macros?|protein|carbs?|carbohydrates?|fats?|recipes?|breakfast|lunch|dinner|snacks?|water|hydrate|hydration|thirst|sodium|fiber|sugar)\b|'
      r'nutrición|comida|alimento|repas|alimentation|ernährung|mahlzeit|cibo|nutrizione|refeição|beslenme|yemek|voeding|posiłek|żywienie|еда|питание|їжа|харчування|makanan|nutrisi|ăn uống|'
      r'خوراک|غذا|کھانا|पोषण|भोजन|পুষ্টি|খাবার|โภชนาการ|อาหาร|营养|營養|食事|영양|음식|'
      r'غذاء|تغذية|وجبة|وجبات|طعام|أكل|اكل|حمية|دايت|سعرات|سعرة|ماكرو|بروتين|كارب|كربوهيدرات|دهون|دهن|وصفة|فطور|غداء|عشاء|سناك|ماء|ميه|ترطيب|عطش|صوديوم|ألياف|الياف|سكر',
      unicode: true,
    ),
  )) {
    categories.add(CoachCloudContextCategory.nutritionAndWater);
  }
  if (has(
    RegExp(
      r'\b(exercises?|workouts?|training|train|activity|activity level|steps?|walk|walking|run|running|gym|cardio|strength|burned|burnt)\b|'
      r'ejercicio|entrenamiento|exercice|entraînement|allenamento|esercizio|exercício|treino|egzersiz|antrenman|oefening|ćwiczenie|trening|упражнение|тренировка|вправа|тренування|latihan|olahraga|tập luyện|'
      r'ورزش|تمرین|व्यायाम|অনুশীলন|ออกกำลัง|锻炼|鍛鍊|運動|운동|'
      r'تمرين|تمارين|تدريب|نشاط|نشط|خطوات|مشي|ركض|جري|جيم|كارديو|مقاومة|محروقة|حرق',
      unicode: true,
    ),
  )) {
    categories.add(CoachCloudContextCategory.trainingAndActivity);
  }
  return categories;
}

/// Projects a least-privilege context for this question and emits a disclosure
/// whose field list is derived from the final payload, so the two cannot drift.
CoachCloudContextProjection projectCoachCloudContext({
  required String question,
  required CoachContextSnapshot context,
  List<CoachConversationTurn> conversation = const [],
}) {
  final categories = _preparedCoachCloudCategories(
    question: question,
    context: context,
    conversation: conversation,
  );
  final topic = _coachCloudScopeText(question, conversation);
  final strictCategoryScope =
      _isCoachDayReview(topic) &&
      _coachDayReviewCategories(topic).length <
          CoachCloudContextCategory.values.length;
  final full = context.toJson();
  final projected = <String, Object?>{
    'schema': full['schema'],
    'generatedAt': full['generatedAt'],
  };
  final profile = _projectCoachProfile(
    context.profile,
    categories,
    strictCategoryScope: strictCategoryScope,
  );
  if (profile.isNotEmpty) projected['profile'] = profile;

  if (categories.contains(
    CoachCloudContextCategory.weightMeasurementsAndGoal,
  )) {
    final weight = Map<String, Object?>.from(full['weight']! as Map);
    weight['history'] = context.weights
        .take(60)
        .map((item) => item.toJson())
        .toList(growable: false);
    projected['weight'] = weight;
  }
  if (categories.contains(CoachCloudContextCategory.nutritionAndWater)) {
    projected['nutritionHistory'] = _boundedNutritionDays(context);
    projected['waterHistory'] = context.waterHistory
        .take(30)
        .toList(growable: false);
  }

  final computed = _projectComputedHealth(
    context.computedHealth,
    categories,
    strictCategoryScope: strictCategoryScope,
  );
  if (computed.isNotEmpty) projected['computedHealth'] = computed;

  if (categories.contains(
    CoachCloudContextCategory.weightMeasurementsAndGoal,
  )) {
    final intelligence = _projectCanonicalIntelligence(
      context.canonicalIntelligence,
    );
    if (intelligence.isNotEmpty) {
      projected['canonicalIntelligence'] = intelligence;
    }
  }
  if (categories.contains(CoachCloudContextCategory.trainingAndActivity) ||
      categories.contains(CoachCloudContextCategory.sleepAndHabits)) {
    projected['activityHistory'] = context.activityHistory
        .take(14)
        .map((entry) => _scopedActivityEntry(entry, categories))
        .where((entry) => entry.length > 1)
        .toList(growable: false);
  }
  if (categories.contains(CoachCloudContextCategory.sleepAndHabits)) {
    projected['bodyContextHistory'] = context.bodyContextHistory
        .take(42)
        .toList(growable: false);
  }
  // A separate opt-in prepares this field. The existing question/category
  // projector still limits what can leave the device after Gemini consent.
  if (context.smartPlan.isNotEmpty &&
      (categories.contains(CoachCloudContextCategory.trainingAndActivity) ||
          categories.contains(CoachCloudContextCategory.nutritionAndWater))) {
    projected['smartPlan'] = <String, Object?>{
      for (final key in const [
        'provenance',
        'planId',
        'revision',
        'updatedAt',
        'horizon',
        'status',
        'today',
        'hasScheduledDay',
        'proposalsAreNotDiaryEntries',
      ])
        if (context.smartPlan.containsKey(key)) key: context.smartPlan[key],
      if (categories.contains(CoachCloudContextCategory.trainingAndActivity))
        for (final key in const ['dueWorkouts', 'confirmedWorkouts'])
          if (context.smartPlan.containsKey(key)) key: context.smartPlan[key],
      if (categories.contains(
        CoachCloudContextCategory.trainingAndActivity,
      )) ...{
        if (context.smartPlan['plannedWorkout'] is Map)
          'plannedWorkout': _projectSmartPlanWorkout(
            context.smartPlan['plannedWorkout'] as Map,
          ),
        if (context.smartPlan['trainingPreferences'] is Map)
          'trainingPreferences': _projectSmartPlanPreferences(
            context.smartPlan['trainingPreferences'] as Map,
          ),
        if (context.smartPlan['trainingWeek'] is List)
          'trainingWeek': (context.smartPlan['trainingWeek'] as List)
              .whereType<Map>()
              .take(7)
              .where(
                (day) =>
                    day['date'] is String &&
                    RegExp(
                      r'^\d{4}-\d{2}-\d{2}$',
                    ).hasMatch(day['date'] as String),
              )
              .map(
                (day) => {
                  'date': day['date'],
                  'workout': day['workout'] is Map
                      ? _projectSmartPlanWorkout(day['workout'] as Map)
                      : null,
                },
              )
              .toList(growable: false),
      },
      if (categories.contains(CoachCloudContextCategory.nutritionAndWater) &&
          context.smartPlan.containsKey('mealSuggestions'))
        'mealSuggestions': context.smartPlan['mealSuggestions'],
      if (context.smartPlan['recentChanges'] is List)
        'recentChanges': (context.smartPlan['recentChanges'] as List)
            .whereType<Map>()
            .where(
              (change) =>
                  change['reason'] == 'status' ||
                  (categories.contains(
                        CoachCloudContextCategory.nutritionAndWater,
                      ) &&
                      change['reason'] == 'mealSwap') ||
                  (categories.contains(
                        CoachCloudContextCategory.trainingAndActivity,
                      ) &&
                      const {
                        'completion',
                        'correction',
                        'schedule',
                        'travel',
                        'fatigue',
                        'equipment',
                      }.contains(change['reason'])),
            )
            .take(5)
            .map(
              (change) => {
                for (final key in const ['revision', 'at', 'reason', 'source'])
                  if (change.containsKey(key)) key: change[key],
              },
            )
            .toList(growable: false),
    };
  }
  final relevantMemories = _categoryRelevantEntries(
    context.explicitMemories,
    categories,
    20,
    strictCategoryScope: strictCategoryScope,
  );
  if (relevantMemories.isNotEmpty) {
    projected['explicitMemories'] = relevantMemories;
  }
  final relevantDecisions = _categoryRelevantEntries(
    context.decisionMemory,
    categories,
    10,
    strictCategoryScope: strictCategoryScope,
  );
  if (relevantDecisions.isNotEmpty) {
    projected['decisionMemory'] = relevantDecisions;
  }
  final relevantExperiments = _categoryRelevantEntries(
    context.personalExperiments,
    categories,
    6,
    strictCategoryScope: strictCategoryScope,
  );
  if (relevantExperiments.isNotEmpty) {
    projected['personalExperiments'] = relevantExperiments;
  }

  var bounded = sanitizeCoachCloudObject(projected);
  bounded = _enforceCoachContextBudget(bounded);
  final includedFields = bounded.keys.toList(growable: false)..sort();
  final categoryNames =
      categories.map((value) => value.wireName).toList(growable: false)..sort();
  final disclosure = <String, Object?>{
    'schema': 'bil.coach-context-disclosure.v1',
    'categories': categoryNames,
    'included_context_fields': includedFields,
  };
  return CoachCloudContextProjection(context: bounded, disclosure: disclosure);
}
