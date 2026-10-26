/// Semantic routing only. No intent is permission to change saved data.
enum CoachRequestKind {
  information,
  savedData,
  nutritionPlan,
  trainingPlan,
  combinedPlan,
  unspecifiedPlan,
  revisePlan,
  reviewProgress,
  recordObservation,
  updateFutureGoal,
  generalHealth,
  completeWorkout,
  todayPlan,
}

class CoachRequestIntent {
  const CoachRequestIntent(this.kind, {this.horizon});
  final CoachRequestKind kind;
  // Existing tool wire values, never a model-invented duration.
  final String? horizon;
  bool get createsPlan => const {
    CoachRequestKind.nutritionPlan,
    CoachRequestKind.trainingPlan,
    CoachRequestKind.combinedPlan,
    CoachRequestKind.unspecifiedPlan,
  }.contains(kind);
  String? get planFocus => switch (kind) {
    CoachRequestKind.nutritionPlan => 'nutrition',
    CoachRequestKind.trainingPlan => 'training',
    CoachRequestKind.combinedPlan => 'combined',
    _ => null,
  };
}

String normalizeCoachMeaning(String input) {
  var text = input
      .toLowerCase()
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll(RegExp('[\u064B-\u065F\u0670ـ]'), '');
  const digits = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < digits.length; i++) {
    text = text.replaceAll(digits[i], '$i');
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Read-only history/chart intent. A weight diary must never be inferred
/// to be a Smart Plan just because the user said "جدول" or "شهر".
bool isCoachWeightHistoryReadRequest(String input) {
  final text = normalizeCoachMeaning(input);
  final weight = RegExp(
    r'\b(?:weights?|weigh|weighing|measurements?)\b|وزن|وزني|اوزاني|اوزان|نزولي|قياسات الجسم',
  ).hasMatch(text);
  if (!weight) return false;
  // An explicit check-in is a different, confirmation-gated health command.
  if (RegExp(
    r'^(?:سجل|ادخل|دخللي|حط|اكتب|دير)\s+(?:لي\s+)?(?:وزني|الوزن)',
  ).hasMatch(text)) {
    return false;
  }
  return RegExp(
    r'\b(?:history|records?|trend|timeline|chart|table|compare|review|analy[sz]e|view|show|past|last)\b|'
    r'اوزاني|اوزان|سجل|القياسات|قياساتي|جدول|تاريخ|قارن|قارنلي|حلل|اطلع|اعرض|استعرض|وريني|نزولي',
  ).hasMatch(text);
}

/// Interpret a short time-window follow-up only for the immediately prior
/// verified weight-read topic. It never authorizes a write or plan draft.
String resolveCoachWeightHistoryFollowUp(
  String current, {
  required String? previousUserRequest,
}) {
  if (previousUserRequest == null ||
      !isCoachWeightHistoryReadRequest(previousUserRequest)) {
    return current;
  }
  final period = normalizeCoachMeaning(current);
  // A short read acknowledgement inherits only the preceding weight topic.
  // Preserve its explicit date range rather than silently reading all time.
  if (const <String>{
    'اطلع',
    'اعرض',
    'وريني',
    'استعرض',
    'show',
    'show it',
    'view',
    'go ahead',
  }.contains(period)) {
    return previousUserRequest;
  }
  if (!RegExp(
    r'^(?:last |for )?(?:week|two weeks|2 weeks|14 days|month|one month|30 days|year|'
    r'اسبوع|الاسبوع|اسبوعين|شهر|الشهر|شهر واحد|عام|سنه|سنة|اخر شهر|اخر اسبوعين)$',
  ).hasMatch(period)) {
    return current;
  }
  return 'weight history $period';
}

/// Negating or correcting an assistant's plan suggestion is not permission
/// to create a draft or launch a native editor.
bool isCoachPlanNegated(String input) {
  final text = normalizeCoachMeaning(input);
  return RegExp(
    r'^(?:لا|ما|مش|مو|ليس|no|not|do not|dont|don.t)\s+'
    r'(?:(?:اريد|بدي|ابي|ابغى|عايز|want|need|create|make|open)\s+)?'
    r'(?:خطه|خطة|جدول|برنامج|plan|schedule)',
  ).hasMatch(text);
}

/// Model-suggested Smart Plan actions are only presentable when the member
/// explicitly requested a plan operation. Review/analysis questions cannot
/// create or launch a plan as an unsolicited side effect.
bool coachAllowsSuggestedPlanAction(String input) {
  if (isCoachPlanNegated(input) || isCoachWeightHistoryReadRequest(input)) {
    return false;
  }
  final intent = classifyCoachRequest(input);
  return intent.createsPlan ||
      const <CoachRequestKind>{
        CoachRequestKind.todayPlan,
        CoachRequestKind.revisePlan,
        CoachRequestKind.completeWorkout,
      }.contains(intent.kind);
}

CoachRequestIntent classifyCoachRequest(String input) {
  final text = normalizeCoachMeaning(input);
  bool has(String pattern) => RegExp(pattern).hasMatch(text);
  if (isCoachWeightHistoryReadRequest(input)) {
    return const CoachRequestIntent(CoachRequestKind.savedData);
  }
  if (isCoachPlanNegated(input)) {
    return const CoachRequestIntent(CoachRequestKind.information);
  }
  final plan = has(r'\bplans?\b|خط[ةه]|خطتي|برنامج|جدول');
  final training = has(
    r'\b(workouts?|training|exercise|gym)\b|تمرين|تمارين|تدريب|جيم',
  );
  final nutrition = has(
    r'\b(nutrition|diet|food|meals?)\b|غذاء|غذائي|تغذي[ةه]|وجبات|اكل',
  );
  // A question about completion reads the diary; punctuation must never turn
  // a status question into the user's assertion that an activity happened.
  if (training &&
      has(r'\b(finished|completed|done)\b|خلصت|انهيت|اكملت') &&
      (has(r'\b(have i|did i|was my|is my|has my)\b|^هل\b') ||
          text.endsWith('?') ||
          text.endsWith('؟'))) {
    return const CoachRequestIntent(CoachRequestKind.savedData);
  }
  final missed = has(
    r'\b(didn.t|couldn.t|not|missed|unable)\b.*\b(workout|train|finish|complete)\w*|ما قدرت|ما تمرنت|ما خلصت|لم اتمرن|لم اكمل|فاتني',
  );
  if (missed && !has(r'\b(change|adjust|revise)\b|غير|عدل|بدل')) {
    return const CoachRequestIntent(CoachRequestKind.reviewProgress);
  }
  if (training && has(r'\b(finished|completed|done)\b|خلصت|انهيت|اكملت')) {
    return const CoachRequestIntent(CoachRequestKind.completeWorkout);
  }
  if ((plan || training) &&
      has(
        r'\b(change|revise|adjust|reschedule|swap)\b|غير|عدل|بدل|تعديل|اجل',
      )) {
    return const CoachRequestIntent(CoachRequestKind.revisePlan);
  }
  if ((training || nutrition) &&
      has(r'\btoday\b|اليوم') &&
      // Reviewing recorded nutrition or training is a read, even when it
      // mentions today. It does not authorize a suggested plan operation.
      !has(r'\b(review|analy[sz]e)\b|راجع|مراجعة|حلل') &&
      !has(
        r'\b(ate|eaten|had|log|logged|record|recorded|add|added)\b|اكلت|تناولت|سجل|اضف',
      )) {
    return const CoachRequestIntent(CoachRequestKind.todayPlan);
  }
  // Future intent always wins over a number that resembles a measurement.
  if (!plan &&
      has(r'\b(goal|target|aim)\b|هدفي|الوزن المستهدف|هدف') &&
      !has(
        r'\blog\b.*\b(?:current|measured) weight\b|سجل وزني (?:الحالي|المقاس)',
      )) {
    return const CoachRequestIntent(CoachRequestKind.updateFutureGoal);
  }
  if (!plan && has(r'\b(log|record|ate|eaten|drank)\b|سجل|اكلت|تناولت|شربت')) {
    return const CoachRequestIntent(CoachRequestKind.recordObservation);
  }
  if (plan &&
      has(
        r'\b(need|want|create|make|build|prepare)\b|بدي|اريد|احتاج|ابغ[ىي]|ابي|عا[يو]ز|اعمل|انش|جهز',
      )) {
    final String? horizon;
    if (has(r'\b(6|six)\s*months?\b|6\s*اشهر|ست[ةه]\s*اشهر|نصف سن[ةه]')) {
      horizon = 'sixMonths';
    } else if (has(r'\b(3|three)\s*months?\b|3\s*اشهر|ثلاث[ةه]?\s*اشهر')) {
      horizon = 'threeMonths';
    } else if (has(r'\b(month|monthly)\b|شهر')) {
      horizon = 'month';
    } else if (has(r'\b(week|weekly|7 days)\b|اسبوع')) {
      horizon = 'week';
    } else {
      horizon = null;
    }
    return CoachRequestIntent(
      training && nutrition
          ? CoachRequestKind.combinedPlan
          : training
          ? CoachRequestKind.trainingPlan
          : nutrition
          ? CoachRequestKind.nutritionPlan
          : CoachRequestKind.unspecifiedPlan,
      horizon: horizon,
    );
  }
  if (has(
    r'\b(progress|review|trend|missed)\b|تقدم|راجع|مراجعة|ما قدرت|فاتني',
  )) {
    return const CoachRequestIntent(CoachRequestKind.reviewProgress);
  }
  if (plan || has(r'\b(my|saved|recorded)\b|المحفوظ|مسجل|وزني|هدفي')) {
    return const CoachRequestIntent(CoachRequestKind.savedData);
  }
  if (has(
    r'\b(health|healthy|symptoms?|injury|allerg)\w*|صح[ةي]|اعراض|اصاب[ةه]|حساسي[ةه]',
  )) {
    return const CoachRequestIntent(CoachRequestKind.generalHealth);
  }
  return const CoachRequestIntent(CoachRequestKind.information);
}

/// Only a bounded plan-slot answer can inherit an adjacent user request.
/// Assistant text, old unrelated turns, numbers and diary commands cannot.
CoachRequestIntent classifyCoachPlanFollowUp(String input, String? previous) {
  final direct = classifyCoachRequest(input);
  if (direct.kind != CoachRequestKind.information || previous == null) {
    return direct;
  }
  final value = normalizeCoachMeaning(input).replaceAll(RegExp(r'[.!؟?]$'), '');
  if (!RegExp(
    r'^(?:(?:for|لمدة)\s+)?(?:one week|a week|week|اسبوع|شهر|شهر واحد|one month|a month|month|3 months|three months|3 اشهر|ثلاثة اشهر|6 months|six months|6 اشهر|ستة اشهر|training only|nutrition only|both|تمارين فقط|غذاء فقط|الاثنين|كلاهما)$',
  ).hasMatch(value)) {
    return direct;
  }
  final prior = classifyCoachRequest(previous);
  if (!prior.createsPlan) return direct;
  final slot = classifyCoachRequest('I need a plan $value');
  final kind = switch (value) {
    'training only' || 'تمارين فقط' => CoachRequestKind.trainingPlan,
    'nutrition only' || 'غذاء فقط' => CoachRequestKind.nutritionPlan,
    'both' || 'الاثنين' || 'كلاهما' => CoachRequestKind.combinedPlan,
    _ => prior.kind,
  };
  return CoachRequestIntent(kind, horizon: slot.horizon ?? prior.horizon);
}

CoachRequestIntent classifyCoachPlanSequence(Iterable<String> recentUserTurns) {
  var resolved = const CoachRequestIntent(CoachRequestKind.information);
  final bounded = recentUserTurns.toList();
  for (final text in bounded.skip(
    bounded.length > 6 ? bounded.length - 6 : 0,
  )) {
    final prior = resolved.createsPlan
        ? 'I need a ${switch (resolved.kind) {
            CoachRequestKind.trainingPlan => 'training',
            CoachRequestKind.nutritionPlan => 'nutrition',
            CoachRequestKind.combinedPlan => 'training nutrition',
            _ => '',
          }} plan ${switch (resolved.horizon) {
            'week' => 'one week',
            'month' => 'one month',
            'threeMonths' => 'three months',
            'sixMonths' => 'six months',
            _ => '',
          }}'
        : null;
    resolved = classifyCoachPlanFollowUp(text, prior);
  }
  return resolved;
}
