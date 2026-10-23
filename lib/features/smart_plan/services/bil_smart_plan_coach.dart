import '../../intelligence_center/domain/bil_tool_registry.dart';
import '../../intelligence_center/domain/intelligence_action.dart';
import '../../intelligence_center/services/coach_request_intent.dart';
import '../domain/bil_smart_plan.dart';

/// Local intent recognition does not call or charge an AI provider. Goals and
/// questions are never interpreted as observations or completed workouts.
enum BilSmartPlanIntent { none, open, today, revise, completedWorkout }

BilSmartPlanIntent smartPlanIntent(String input) {
  final semantic = classifyCoachRequest(input);
  if (semantic.createsPlan) return BilSmartPlanIntent.open;
  if (semantic.kind == CoachRequestKind.completeWorkout) {
    return BilSmartPlanIntent.completedWorkout;
  }
  if (semantic.kind == CoachRequestKind.revisePlan) {
    return BilSmartPlanIntent.revise;
  }
  if (semantic.kind == CoachRequestKind.todayPlan) {
    return BilSmartPlanIntent.today;
  }
  if ({
    CoachRequestKind.reviewProgress,
    CoachRequestKind.updateFutureGoal,
    CoachRequestKind.recordObservation,
  }.contains(semantic.kind)) {
    return BilSmartPlanIntent.none;
  }
  if (semantic.kind == CoachRequestKind.savedData &&
      RegExp(
        r'\b(finished|completed|done)\b|خلصت|انهيت|اكملت',
      ).hasMatch(normalizeCoachMeaning(input))) {
    return BilSmartPlanIntent.none;
  }
  final text = input.toLowerCase().replaceAll(RegExp('[أإآ]'), 'ا');
  if (RegExp(
        r'\b(goal|target|aim|weigh|weight)\b|وزن|هدفي|هدف',
      ).hasMatch(text) &&
      !RegExp(r'\bplan\b|خطة|خطه|خطتي').hasMatch(text)) {
    return BilSmartPlanIntent.none;
  }
  // Observations and diary commands belong to the existing confirmed logging
  // flow. In particular, Arabic "اكلت ... اليوم" is not a plan preview.
  final explicitPlan = RegExp(r'\bplan\b|خطة|خطه|خطتي').hasMatch(text);
  if (!explicitPlan &&
      RegExp(
        r'\b(ate|eaten|had|log|logged|record|recorded|add|added)\b|اكلت|تناولت|سجل|سجّل',
      ).hasMatch(text)) {
    return BilSmartPlanIntent.none;
  }
  if (RegExp(
    r'\b(finished|completed) (my |the )?(planned )?workout\b|انهيت تمرين|اكملت تمرين',
  ).hasMatch(text)) {
    return BilSmartPlanIntent.completedWorkout;
  }
  if (RegExp(
    r"\b(workout|training|meals?|food)\b.*\btoday\b|\btoday.?s (workout|meals?)\b|تمرين.*اليوم|وجبات.*اليوم|اكل.*اليوم",
  ).hasMatch(text)) {
    return BilSmartPlanIntent.today;
  }
  if (RegExp(
    r'\b(change|revise|adjust)\b.*\bplan\b|عدل.*خط|تعديل.*خط',
  ).hasMatch(text)) {
    return BilSmartPlanIntent.revise;
  }
  if (RegExp(
    r'\b(my plan|smart plan|need (to |a )?plan|create (a )?plan|make (a )?plan)\b|خطتي|اريد خط[ةه]|بدي خط[ةه]|انش.*خط[ةه]',
  ).hasMatch(text)) {
    return BilSmartPlanIntent.open;
  }
  return BilSmartPlanIntent.none;
}

/// A weight target with a one-week deadline requires review; it is not an
/// observed weight and must not silently become a nutrition prescription.
bool smartPlanGoalNeedsReview(String input) {
  final text = input.toLowerCase().replaceAll(RegExp('[أإآ]'), 'ا');
  return RegExp(r'\d').hasMatch(text) &&
      RegExp(
        r'\b(kg|kilograms?|weight|target|goal)\b|كيلو|اوص?ل|وزن|هدفي',
      ).hasMatch(text) &&
      RegExp(
        r'\b(week|7 days|seven days)\b|اسبوع|سبعة ايام|7 ايام',
      ).hasMatch(text);
}

/// A bounded projection of durable data, never an invented chat memory.
/// Consumers must still apply Gemini consent and category selection.
Map<String, Object?> smartPlanContext(
  BilSmartPlan plan,
  DateTime today, {
  required bool includeTraining,
  required bool includeNutrition,
  bool includeExtendedContext = false,
}) {
  if (!includeTraining && !includeNutrition) return const {};
  final day = plan.onDate(today);
  final due = plan.days.where(
    (d) => d.date.compareTo(BilPlanDate.iso(today)) <= 0 && d.workout != null,
  );
  return {
    'provenance': 'owner_scoped_saved_smart_plan',
    'planId': plan.id,
    'revision': plan.revision,
    'updatedAt': plan.updatedAt.toUtc().toIso8601String(),
    'horizon': plan.horizon.name,
    'status': plan.status.name,
    'today': BilPlanDate.iso(today),
    'hasScheduledDay': day != null,
    if (includeTraining) ...{
      'dueWorkouts': due.length,
      'confirmedWorkouts': due.where((d) => d.workout!.completed).length,
      if (day?.workout case final workout?) 'plannedWorkout': workout.toJson(),
      if (includeExtendedContext && plan.setup != null)
        'trainingPreferences': {
          'source': 'confirmed_plan_setup',
          'updatedAt': plan.createdAt.toUtc().toIso8601String(),
          'environment': plan.setup!.environment.name,
          'experience': plan.setup!.experience.name,
          'sessionMinutes': plan.setup!.sessionMinutes,
          'equipment': plan.setup!.equipment.toList()..sort(),
          if (plan.setup!.preferredTime != null)
            'preferredTime': plan.setup!.preferredTime,
        },
      if (includeExtendedContext)
        'trainingWeek': [
          for (final scheduled in plan.days.where((entry) {
            final delta = BilPlanDate.parse(
              entry.date,
            ).difference(BilPlanDate.atMidnight(today)).inDays;
            return delta >= -3 && delta <= 3;
          }))
            {'date': scheduled.date, 'workout': scheduled.workout?.toJson()},
        ],
    },
    if (includeNutrition && day != null)
      'mealSuggestions': day.meals.map((meal) => meal.toJson()).toList(),
    if (includeExtendedContext)
      'recentChanges': [
        for (final change
            in plan.changes
                .where(
                  (change) =>
                      change.reason == BilPlanChangeReason.status ||
                      (includeNutrition &&
                          change.reason == BilPlanChangeReason.mealSwap) ||
                      (includeTraining &&
                          change.reason != BilPlanChangeReason.mealSwap),
                )
                .take(5))
          {
            'revision': change.revision,
            'at': change.at.toUtc().toIso8601String(),
            'reason': change.reason.name,
            'source': 'confirmed_plan_revision',
          },
      ],
    'proposalsAreNotDiaryEntries': true,
  };
}

class BilSmartPlanTool extends BilToolDescriptor {
  const BilSmartPlanTool({
    required super.name,
    required bool readOnly,
    super.requiredArguments,
    super.allowedArguments,
  }) : super(
         type: IntelligenceActionType.smartPlan,
         risk: readOnly ? BilToolRisk.readOnly : BilToolRisk.reversibleWrite,
         minimumTier: BilToolTier.premium,
         trustBoundary: BilToolTrustBoundary.trustedLocalRepository,
       );

  @override
  Map<String, Object?>? validateArguments(Map<String, Object?> raw) {
    if (!raw.keys.every(allowedArguments.contains) ||
        !requiredArguments.every(raw.containsKey)) {
      return null;
    }
    if (raw['planId'] case final id?) {
      if (id is! String ||
          !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$').hasMatch(id)) {
        return null;
      }
    }
    if (raw['revision'] case final revision?) {
      if (revision is! int || revision < 1) return null;
    }
    if (raw['date'] case final date?) {
      try {
        BilPlanDate.parse(date as String);
      } on Object {
        return null;
      }
    }
    if (raw['horizon'] case final horizon?) {
      if (!BilPlanHorizon.values.any((v) => v.name == horizon)) return null;
    }
    if (raw['focus'] case final focus?) {
      if (!BilPlanFocus.values.any((v) => v.name == focus)) return null;
    }
    return Map.unmodifiable(raw);
  }
}

const smartPlanTools = <String, BilToolDescriptor>{
  'read_active_smart_plan': BilSmartPlanTool(
    name: 'read_active_smart_plan',
    readOnly: true,
  ),
  'preview_smart_plan_day': BilSmartPlanTool(
    name: 'preview_smart_plan_day',
    readOnly: true,
    allowedArguments: {'date'},
  ),
  // All changes open the native editor. A model cannot approve a plan or
  // confirm performed exercise. Success comes back only after saved readback.
  'create_smart_plan_draft': BilSmartPlanTool(
    name: 'create_smart_plan_draft',
    readOnly: false,
    allowedArguments: {'horizon', 'focus'},
  ),
  'request_smart_plan_revision': BilSmartPlanTool(
    name: 'request_smart_plan_revision',
    readOnly: false,
    requiredArguments: {'planId', 'revision'},
    allowedArguments: {'planId', 'revision'},
  ),
  'record_smart_plan_workout': BilSmartPlanTool(
    name: 'record_smart_plan_workout',
    readOnly: false,
    requiredArguments: {'planId', 'revision', 'date'},
    allowedArguments: {'planId', 'revision', 'date'},
  ),
};

/// Not an authorization token. The native page rechecks identity, revision,
/// entitlement and user confirmation before every mutation.
class BilSmartPlanToolRequest {
  const BilSmartPlanToolRequest(
    this.toolId,
    this.arguments, {
    this.checkAccess,
    this.revisionHint,
  });
  final void Function()? checkAccess;

  /// Local navigation hint from the user's message, never a tool wire field
  /// or authorization to edit the plan.
  final BilSmartPlanRevisionHint? revisionHint;
  final String toolId;
  final Map<String, Object?> arguments;
}

class BilSmartPlanRevisionHint {
  const BilSmartPlanRevisionHint({this.weekday, required this.reason});
  final int? weekday;
  final BilPlanChangeReason reason;

  static BilSmartPlanRevisionHint fromUserText(String input) {
    final text = normalizeCoachMeaning(input);
    const weekdays = {
      'monday|الاثنين|الاثنان': DateTime.monday,
      'tuesday|الثلاثاء|الثلاثا': DateTime.tuesday,
      'wednesday|الاربعاء|الاربعا': DateTime.wednesday,
      'thursday|الخميس': DateTime.thursday,
      'friday|الجمعه|الجمعة': DateTime.friday,
      'saturday|السبت': DateTime.saturday,
      'sunday|الاحد': DateTime.sunday,
    };
    final days = weekdays.entries.where((e) => RegExp(e.key).hasMatch(text));
    return BilSmartPlanRevisionHint(
      weekday: days.length == 1 ? days.single.value : null,
      reason:
          RegExp(
            r'\b(travel|travelling|traveling|trip)\b|مسافر|سفر',
          ).hasMatch(text)
          ? BilPlanChangeReason.travel
          : RegExp(
              r'\b(tired|fatigue|exhausted|rest)\b|تعب|مرهق|راحة',
            ).hasMatch(text)
          ? BilPlanChangeReason.fatigue
          : RegExp(
              r'\b(equipment|dumbbells?|gym)\b|معدات|اجهزة|ادوات',
            ).hasMatch(text)
          ? BilPlanChangeReason.equipment
          : BilPlanChangeReason.schedule,
    );
  }

  BilPlanDay? session(BilSmartPlan plan, DateTime today) {
    if (weekday == null) return null;
    return plan.days
        .where(
          (day) =>
              day.date.compareTo(BilPlanDate.iso(today)) >= 0 &&
              BilPlanDate.parse(day.date).weekday == weekday &&
              day.workout != null &&
              !day.workout!.completed,
        )
        .firstOrNull;
  }
}
