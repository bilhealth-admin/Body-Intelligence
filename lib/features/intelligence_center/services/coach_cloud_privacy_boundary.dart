import 'dart:convert';

import '../domain/coach_context_snapshot.dart';
import 'coach_cloud_payload_sanitizer.dart';
import 'local_model_gateway.dart';

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
    raw is Map && raw['granted'] == true && raw['policy_version'] == '2';

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
  final direct = _coachCloudCategoriesInText(question);
  if (direct.isNotEmpty) return direct;
  for (final turn in conversation.reversed) {
    if (turn.role != 'user') continue;
    final prior = turn.content.trim();
    if (prior.isEmpty || prior == question.trim()) continue;
    return _coachCloudCategoriesInText(prior);
  }
  return const <CoachCloudContextCategory>{};
}

/// Keeps only prior user/assistant turns whose detected categories are a
/// subset of the latest question's scope. General questions send no history;
/// the latest question itself is appended separately by the gateway.
List<CoachConversationTurn> questionScopedCoachCloudConversation({
  required String question,
  List<CoachConversationTurn> conversation = const [],
}) {
  final categories = coachCloudContextCategoriesForQuestion(
    question: question,
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
  final retained = <CoachConversationTurn>[];
  var relevantUserTurn = false;
  for (final turn in values) {
    final turnCategories = _coachCloudCategoriesInText(turn.content);
    final isSubset = turnCategories.every(categories.contains);
    if (turn.role == 'user') {
      relevantUserTurn = turnCategories.isNotEmpty && isSubset;
      if (relevantUserTurn) retained.add(turn);
      continue;
    }
    if (relevantUserTurn && isSubset) retained.add(turn);
  }
  return retained.length <= 6
      ? retained
      : retained.sublist(retained.length - 6);
}

Set<CoachCloudContextCategory> _coachCloudCategoriesInText(String source) {
  final text = source.toLowerCase();
  final categories = <CoachCloudContextCategory>{};
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
      r'peso|poids|gewicht|waga|ağırlık|berat|cân nặng|вес|вага|وزن|वज़न|ওজন|น้ำหนัก|体重|體重|체중|'
      r'هدف الوزن|وزني المستهدف|الوزن المستهدف|خصر|ورك|أرداف|ارداف|رقبة|صدر|ذراع|فخذ|قياس|كتلة الجسم|كيلو',
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
  final categories = coachCloudContextCategoriesForQuestion(
    question: question,
    conversation: conversation,
  );
  final full = context.toJson();
  final projected = <String, Object?>{
    'schema': full['schema'],
    'generatedAt': full['generatedAt'],
  };
  final profile = _projectCoachProfile(context.profile, categories);
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

  final computed = _projectComputedHealth(context.computedHealth, categories);
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
  final relevantMemories = _categoryRelevantEntries(
    context.explicitMemories,
    categories,
    20,
  );
  if (relevantMemories.isNotEmpty) {
    projected['explicitMemories'] = relevantMemories;
  }
  final relevantDecisions = _categoryRelevantEntries(
    context.decisionMemory,
    categories,
    10,
  );
  if (relevantDecisions.isNotEmpty) {
    projected['decisionMemory'] = relevantDecisions;
  }
  final relevantExperiments = _categoryRelevantEntries(
    context.personalExperiments,
    categories,
    6,
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

Map<String, Object?> _projectCoachProfile(
  Map<String, Object?> profile,
  Set<CoachCloudContextCategory> categories,
) {
  final keys = <String>{};
  if (categories.contains(
    CoachCloudContextCategory.weightMeasurementsAndGoal,
  )) {
    keys.addAll(const <String>{
      'age',
      'gender',
      'heightCm',
      'currentWeightKg',
      'targetWeightKg',
      'waistCm',
      'neckCm',
      'hipCm',
      'chestCm',
      'armCm',
      'thighCm',
      'selectedGoals',
      'goalConsumers',
    });
  }
  if (categories.contains(CoachCloudContextCategory.nutritionAndWater)) {
    keys.addAll(const <String>{
      'age',
      'gender',
      'heightCm',
      'currentWeightKg',
      'targetWeightKg',
      'activityLevel',
      'dietaryPreferences',
      'selectedGoals',
      'goalConsumers',
    });
  }
  if (categories.contains(CoachCloudContextCategory.trainingAndActivity)) {
    keys.addAll(const <String>{
      'age',
      'gender',
      'heightCm',
      'currentWeightKg',
      'activityLevel',
      'exercises',
      'selectedGoals',
      'goalConsumers',
    });
  }
  if (categories.contains(CoachCloudContextCategory.sleepAndHabits)) {
    keys.addAll(const <String>{'selectedGoals', 'goalConsumers'});
  }
  return <String, Object?>{
    for (final key in keys)
      if (profile.containsKey(key) && profile[key] != null) key: profile[key],
  };
}

const Set<String> _weightComputedHealthKeys = <String>{
  'status',
  'bodyModelVersion',
  'goalDirection',
  'kilogramsToGoal',
  'bmrKcal',
  'tdeeKcal',
  'bmiScreeningValue',
  'waistToHeightRatio',
  'expectedBodyFatPercent',
  'expectedFatFreeMassKg',
  'bodyFatEstimateMethod',
  'bodyFatEstimateUncertainty',
  'bodyFatEstimateIssue',
  'healthyWaistScreeningUpperCm',
  'obesityRiskScreening',
  'notice',
};

Map<String, Object?> _projectComputedHealth(
  Map<String, Object?> health,
  Set<CoachCloudContextCategory> categories,
) {
  if (categories.isEmpty) return const <String, Object?>{};
  final result = <String, Object?>{};
  if (health['status'] != null) result['status'] = health['status'];
  if (categories.contains(
    CoachCloudContextCategory.weightMeasurementsAndGoal,
  )) {
    for (final key in _weightComputedHealthKeys) {
      if (health.containsKey(key) && health[key] != null) {
        result[key] = health[key];
      }
    }
  }
  if (categories.contains(CoachCloudContextCategory.nutritionAndWater)) {
    for (final key in const <String>{
      'dailyTargets',
      'dailyTargetSources',
      'mealTargets',
    }) {
      if (health.containsKey(key) && health[key] != null) {
        result[key] = health[key];
      }
    }
  }
  if (categories.contains(CoachCloudContextCategory.trainingAndActivity)) {
    for (final key in const <String>{'bmrKcal', 'tdeeKcal'}) {
      if (health.containsKey(key) && health[key] != null) {
        result[key] = health[key];
      }
    }
  }
  final source = health['today'];
  if (source is Map) {
    final today = <String, Object?>{};
    if (source['day'] != null) today['day'] = source['day'];
    if (categories.contains(CoachCloudContextCategory.nutritionAndWater) &&
        source['nutrition'] != null) {
      today['nutrition'] = source['nutrition'];
    }
    if (categories.contains(CoachCloudContextCategory.trainingAndActivity) &&
        source['exerciseEnergy'] != null) {
      today['exerciseEnergy'] = source['exerciseEnergy'];
    }
    if (categories.contains(CoachCloudContextCategory.sleepAndHabits)) {
      for (final key in const <String>{'sleep', 'fasting', 'bodyContext'}) {
        if (source[key] != null) today[key] = source[key];
      }
    }
    if (today.isNotEmpty) result['today'] = today;
  }
  return result;
}

Map<String, Object?> _projectCanonicalIntelligence(
  Map<String, Object?> source,
) {
  const keys = <String>{
    'status',
    'canPresent',
    'confidence',
    'bodyTwin',
    'adaptiveTdeeKcal',
    'plateauRisk',
    'physiologicalNoise',
    'forecast',
  };
  return <String, Object?>{
    for (final key in keys)
      if (source.containsKey(key) && source[key] != null) key: source[key],
  };
}

List<Map<String, Object?>> _boundedNutritionDays(
  CoachContextSnapshot context,
) => context.nutritionDays
    .take(7)
    .map((day) {
      final value = day.toJson();
      final meals = (value['meals']! as List)
          .take(6)
          .map((rawMeal) {
            final meal = Map<String, Object?>.from(rawMeal as Map);
            final items = meal['items'];
            if (items is List) {
              meal['items'] = items.take(12).toList(growable: false);
            }
            return meal;
          })
          .toList(growable: false);
      return <String, Object?>{...value, 'meals': meals};
    })
    .toList(growable: false);

Map<String, Object?> _scopedActivityEntry(
  Map<String, Object?> source,
  Set<CoachCloudContextCategory> categories,
) {
  final keys = <String>{'day'};
  if (categories.contains(CoachCloudContextCategory.trainingAndActivity)) {
    keys.addAll(const <String>{'steps', 'exercises'});
  }
  if (categories.contains(CoachCloudContextCategory.sleepAndHabits)) {
    keys.addAll(const <String>{
      'sleepHours',
      'sleepSource',
      'sleepDeviceSource',
      'sleepObservedAt',
      'sleepLastSyncAt',
    });
  }
  return <String, Object?>{
    for (final key in keys)
      if (source.containsKey(key) && source[key] != null) key: source[key],
  };
}

List<Map<String, Object?>> _categoryRelevantEntries(
  List<Map<String, Object?>> source,
  Set<CoachCloudContextCategory> categories,
  int limit,
) {
  if (categories.isEmpty) return const <Map<String, Object?>>[];
  return source
      .where((entry) {
        final entryCategories = _coachCloudCategoriesInText(jsonEncode(entry));
        return entryCategories.any(categories.contains);
      })
      .take(limit)
      .toList(growable: false);
}

Map<String, Object?> _enforceCoachContextBudget(Map<String, Object?> source) {
  if (jsonEncode(source).length <= 19_000) return source;
  final bounded = Map<String, Object?>.from(source);
  final nutrition = bounded['nutritionHistory'];
  if (nutrition is List) {
    bounded['nutritionHistory'] = nutrition
        .whereType<Map>()
        .map(
          (day) => <String, Object?>{
            if (day['day'] != null) 'day': day['day'],
            if (day['totals'] != null) 'totals': day['totals'],
            if (day['knownTotals'] != null) 'knownTotals': day['knownTotals'],
          },
        )
        .toList(growable: false);
  }
  final weight = bounded['weight'];
  if (weight is Map) {
    final reduced = Map<String, Object?>.from(weight);
    final history = reduced['history'];
    if (history is List) {
      reduced['history'] = history.take(20).toList(growable: false);
    }
    bounded['weight'] = reduced;
  }
  for (final key in const <String>[
    'bodyContextHistory',
    'activityHistory',
    'decisionMemory',
    'explicitMemories',
    'personalExperiments',
  ]) {
    final values = bounded[key];
    if (values is List) bounded[key] = values.take(6).toList(growable: false);
  }
  var sanitized = sanitizeCoachCloudObject(bounded);
  if (jsonEncode(sanitized).length <= 19_000) return sanitized;
  // Retain summaries and current targets, but never exceed the server limit by
  // forwarding an unexpectedly large row-level record.
  for (final key in const <String>[
    'bodyContextHistory',
    'activityHistory',
    'decisionMemory',
    'explicitMemories',
    'personalExperiments',
    'nutritionHistory',
  ]) {
    sanitized.remove(key);
    if (jsonEncode(sanitized).length <= 19_000) return sanitized;
  }
  final reducedWeight = sanitized['weight'];
  if (reducedWeight is Map) {
    final weightSummary = Map<String, Object?>.from(reducedWeight)
      ..remove('history');
    sanitized['weight'] = weightSummary;
  }
  if (jsonEncode(sanitized).length <= 19_000) return sanitized;
  // Unknown oversized nested values fail closed individually.
  sanitized.remove('canonicalIntelligence');
  sanitized.remove('computedHealth');
  sanitized.remove('profile');
  return sanitizeCoachCloudObject(sanitized);
}
