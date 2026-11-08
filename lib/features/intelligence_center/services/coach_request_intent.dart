import '../domain/coach_question_purpose.dart';

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

const _coachEnglishActionVerbs =
    r'(?:change|modify|edit|adjust|revise|reschedule|swap|log|record|save|add|'
    r'delete|remove|create|make|build|open|start|finish|complete|mark|update|'
    r'write|post|send)';
const _coachArabicActionVerbs =
    r'(?:تغير|تعدل|تبدل|تسجل|تحفظ|تضيف|تحذف|تنشئ|تفتح|تحدث|تكتب|تسوي|تعمل)';

// These existing commands treat everything after the first colon as literal
// content. Only their header can choose an action; the health parser still
// validates the entire header, date and payload before proposing that action.
String _coachDirectiveText(String input) {
  final separator = input.indexOf(':');
  if (separator < 0) return input;
  final header = input.substring(0, separator);
  if (RegExp(
    r'^(?:(?:save|log) (?:a )?note|(?:save|log) life context|'
    r'(?:find|search) health content|سجل ملاحظة|احفظ ملاحظة|'
    r'سجل سياق حياتي|احفظ سياق حياتي|ابحث في المحتوى)(?:\s|$)',
  ).hasMatch(normalizeCoachMeaning(header))) {
    return header;
  }
  return input;
}

/// Explicit global restrictions and answer-only requests suppress actions for
/// this turn. A scoped "do not log weight; update my goal" is not a global veto.
bool coachExplicitlyForbidsActions(String input) {
  final text = normalizeCoachMeaning(
    _coachDirectiveText(input),
  ).replaceAll('’', "'");
  return RegExp(r'\bread[ -]?only\b').hasMatch(text) ||
      RegExp(
        r"\b(?:do not|don't|dont|never)\s+" +
            _coachEnglishActionVerbs +
            r'\b[^.!?;]*\b(?:anything|(?:any|my|our|the) (?:data|records?)|any changes?)\b',
      ).hasMatch(text) ||
      RegExp(
        r'\b(?:only|just)\s+(?:answer|reply|respond|explain)\b|'
        r'\b(?:answer|reply|respond)\s+only\b',
      ).hasMatch(text) ||
      RegExp(
        r'(?:^|[\s.!?،؛؟])(?:لا|ما|مش|مو)\s*' +
            _coachArabicActionVerbs +
            r'[^.!?؛؟]*اي\s*(?:شيء|شي|بيانات|سجلات)',
      ).hasMatch(text) ||
      RegExp(
        r'(?:بدون|دون)[^.!?؛؟]*اي\s*(?:شيء|شي|بيانات|سجلات)|'
        r'(?:بدون|دون)\s+(?:تعديل|تغيير|تسجيل)\s+(?:بياناتي|سجلاتي)|'
        r'(?:للقراءة|قراءة)\s+فقط|'
        r'(?:اشرح|اجب|جاوب)[^.!?؛؟]*\sفقط',
      ).hasMatch(text);
}

/// Remove only an explicitly negated imperative clause before deterministic
/// command matching. Keep a following positive clause, its values and dates.
/// The original turn is still retained for conversation and model reasoning.
String coachActionRequestText(String input) {
  if (_coachDirectiveText(input) != input) return input.trim();
  var text = input.trim().replaceAll('’', "'");
  text = text.replaceAll(
    RegExp(
      r"(?:^|[.!?;،,؛])\s*(?:please\s+)?(?:do not|don't|dont|never)\s+" +
          _coachEnglishActionVerbs +
          r'\b.*?(?=[.!?;،,؛]|\bbut\b|$)',
      caseSensitive: false,
    ),
    ' ',
  );
  text = text.replaceAll(
    RegExp(
      r'(?:^|[.!?;،,؛؟])\s*(?:لا|ما|مش|مو)\s*' +
          _coachArabicActionVerbs +
          r'.*?(?=[.!?;،,؛؟]|لكن|$)',
    ),
    ' ',
  );
  return text
      .replaceFirst(
        RegExp(
          r'^[\s.!?;،,؛؟]*(?:(?:but|however)\b\s*|لكن\s*)?',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
}

// A formatting request cannot turn an explicit check-in/goal update into a
// history read. The existing command parser still validates its quantity/date
// and owns confirmation; this predicate never admits a write itself.
bool _isCoachWeightMutationRequest(String text) => RegExp(
  r'^(?:please[,\s]+)?(?:log|record|save|add)\s+'
  r'(?:(?:my|the|body|current|measured)\s+){0,4}weight\b|'
  r'^(?:please[,\s]+)?(?:set|update|change|modify)\s+'
  r'(?:(?:my|the|new|target|goal)\s+){0,4}(?:weight|goal|target)\b|'
  r'^(?:(?:من فضلك|لو سمحت|ارجوك)\s+)?'
  r'(?:سجل|ادخل|دخللي|حط|اكتب|دير|اضف|غير|عدل|حدث)\s+'
  r'(?:لي\s+)?(?:وزني|الوزن|هدفي|الهدف)',
).hasMatch(text);

/// Definitions/comparisons about weight concepts belong to the normal answer
/// path. "Explain my recorded weight trend in a table" remains a personal read;
/// merely mentioning a table is not evidence that measurements were requested.
bool isCoachWeightConceptQuestion(String input) {
  final text = normalizeCoachMeaning(input);
  if (!RegExp(r'\b(?:weights?|weigh|weighing)\b|وزن').hasMatch(text) ||
      _isCoachWeightMutationRequest(text)) {
    return false;
  }
  final personalHistory = RegExp(
    r'\bmy\s+(?:(?:recorded|saved|logged|recent|past|last|current)\s+){0,3}'
    r'(?:weight\s+)?(?:history|trend|chart|timeline|measurements?|records?|progress)\b|'
    r'\b(?:history|trend|chart|timeline|progress)\s+(?:of\s+)?my\s+weight\b|'
    r'\bmy\s+weight\b[^.!?]{0,60}\b(?:changes?|changed|last|past|over time)\b|'
    r'\bchanges?\s+(?:in|of)\s+my\s+weight\b|'
    r'\b(?:saved|recorded|logged)\s+(?:body\s+)?(?:weights?|measurements?)\b|'
    r'(?:تغير|تطور|اتجاه|تقلب|سجل|تاريخ|نزول|تقدم)\s+(?:في\s+)?(?:وزني|اوزاني|الوزن)|'
    r'(?:وزني|اوزاني)[^.!?؛؟]{0,50}(?:المسجل|المحفوظ|اخر|خلال)',
  ).hasMatch(text);
  if (personalHistory) return false;
  return RegExp(
    r'\b(?:explain|define|definition|meaning)\b|'
    r'\bwhat\b[^.!?]{0,120}\b(?:difference|mean)\b|'
    r'\bdifferences?\s+between\b|'
    r'اشرح|وضح|تعريف|ما\s+معن|الفرق|الفروق',
  ).hasMatch(text);
}

/// Read-only history/chart intent. A weight diary must never be inferred
/// to be a Smart Plan just because the user said "جدول" or "شهر".
bool isCoachWeightHistoryReadRequest(String input) {
  final text = normalizeCoachMeaning(input);
  if (isCoachWeightConceptQuestion(input) ||
      _isCoachWeightMutationRequest(text)) {
    return false;
  }
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

/// A future/conditional completion describes a plan, never an observed event.
/// Shared with the legacy plan fallback so that it cannot re-admit the phrase.
bool isCoachFutureWorkoutCompletion(String input) {
  final text = normalizeCoachMeaning(input);
  final future = RegExp(
    r'\b(?:will|would|going to|plan to|intend to|want to|aim to|if|when|once)\b'
    r'[^.!?;]*\b(?:finish|complete|finished|completed|done)\b|'
    r'(?:راح|رح|سوف|بكره|بكرة|غدا|اذا|عندما|لما)[^.!?؛؟]*(?:خلصت|انهيت|اكملت|اخلص|انهي|اكمل|يكتمل)',
  );
  if (!future.hasMatch(text)) return false;
  // Preserve a separate explicit observation in a mixed turn. A future clause
  // cannot erase "I completed my workout" or turn its review into information.
  final observed = RegExp(
    r"^(?:(?:today|yesterday)\s+)?(?:i(?: have|'ve)?\s+(?:just\s+)?(?:finished|completed|done)\b|"
    r'(?:just\s+)?(?:finished|completed|done)\s+(?:my|the)\b)|'
    r'^(?:(?:اليوم|امس|مبارح)\s+)?(?:انا\s+)?(?:خلصت|انهيت|اكملت)(?:\s|$)',
  );
  final clauses = text.split(
    RegExp(
      r'[.!?;؛؟]+|\s+(?:and|but|then)\s+|'
      r'\s+و(?=(?:راح|رح|سوف|بكره|بكرة|غدا))',
    ),
  );
  return !clauses.any(
    (clause) => observed.hasMatch(clause.trim()) && !future.hasMatch(clause),
  );
}

/// Model-suggested Smart Plan actions are only presentable when the member
/// explicitly requested a plan operation. Review/analysis questions cannot
/// create or launch a plan as an unsolicited side effect.
bool coachAllowsSuggestedPlanAction(String input) {
  if (coachExplicitlyForbidsActions(input) ||
      isCoachPlanNegated(input) ||
      isCoachWeightHistoryReadRequest(input)) {
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
  final text = normalizeCoachMeaning(
    _coachDirectiveText(coachActionRequestText(input)),
  );
  bool has(String pattern) => RegExp(pattern).hasMatch(text);
  if (coachExplicitlyForbidsActions(input)) {
    return const CoachRequestIntent(CoachRequestKind.information);
  }
  if (isCoachWeightConceptQuestion(input)) {
    return const CoachRequestIntent(CoachRequestKind.information);
  }
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
  final completedTraining =
      training && has(r'\b(finished|completed|done)\b|خلصت|انهيت|اكملت');
  if (completedTraining && isCoachFutureWorkoutCompletion(input)) {
    return const CoachRequestIntent(CoachRequestKind.information);
  }
  if (completedTraining &&
      has(
        r"\b(?:not|never|isn.t|wasn.t|hasn.t|haven.t)\s+(?:yet\s+)?(?:finished|completed|done)\b|"
        r'(?:ما|لم|مش|مو)\s*(?:خلصت|انهيت|اكملت)',
      )) {
    return const CoachRequestIntent(CoachRequestKind.reviewProgress);
  }
  // A comparison/definition can mention "completed workout" without asserting
  // that one happened. A real completion or logging command can still request
  // a table; that presentation preference must not cancel its existing review.
  final explanatoryCompletion =
      completedTraining &&
      coachRequestsReasonedOrFormattedAnswer(input) &&
      !has(
        r"^(?:please[,\s]+)?(?:(?:today|yesterday)[,\s]+)?"
        r"(?:(?:log|record|mark|save)\b|"
        r"i(?: have|'ve)?\s+(?:just\s+)?(?:finished|completed|done)\b|"
        r'(?:just\s+)?(?:finished|completed|done)\s+(?:my|the)\b)|'
        r'^(?:(?:اليوم|امس|مبارح)[،,\s]+)?'
        r'(?:انا\s+)?(?:خلصت|انهيت|اكملت)(?:\s|[.!?،؛؟]|$)|'
        r'^(?:(?:من فضلك|لو سمحت|ارجوك)\s+)?'
        r'(?:سجل|دون|احفظ|علم)(?:\s|[.!?،؛؟]|$)',
      );
  // A question about completion reads the diary; punctuation must never turn
  // a status question into the user's assertion that an activity happened.
  if (completedTraining &&
      !explanatoryCompletion &&
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
  if (explanatoryCompletion) {
    return const CoachRequestIntent(CoachRequestKind.information);
  }
  if (completedTraining) {
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
