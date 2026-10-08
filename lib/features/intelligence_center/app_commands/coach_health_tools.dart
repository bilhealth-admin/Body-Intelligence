import '../domain/bil_tool_registry.dart';
import '../domain/intelligence_action.dart';
import 'coach_health_adapter.dart';
import '../intelligence_locale_copy.dart';

String coachHealthActionLabel(String toolId, String locale) {
  final labels = switch (toolId) {
    'close_day' => ('Close day', 'إغلاق اليوم'),
    'reopen_day' => ('Reopen day', 'إعادة فتح اليوم'),
    'log_sleep' => ('Record sleep', 'تسجيل النوم'),
    'save_day_note' => ('Save day note', 'حفظ ملاحظة اليوم'),
    'save_life_context' => ('Save life context', 'حفظ السياق الحياتي'),
    'start_fasting' => ('Start fasting', 'بدء الصيام'),
    'stop_fasting' => ('Stop fasting', 'إنهاء الصيام'),
    'adjust_fasting' => ('Correct fasting session', 'تصحيح جلسة الصيام'),
    'log_exercise' => ('Record performed exercise', 'تسجيل تمرين تم أداؤه'),
    'activate_plan' => ('Review plan activation', 'مراجعة تفعيل الخطة'),
    'preview_plan' => ('Preview plan', 'معاينة الخطة'),
    'read_fasting' => ('Read fasting status', 'قراءة حالة الصيام'),
    'read_health_history' => (
      'Read recorded health history',
      'قراءة السجل الصحي',
    ),
    'read_health_progress' => (
      'Read recorded weight progress',
      'قراءة تقدم الوزن المسجل',
    ),
    'search_health_content' => (
      'Find verified local content',
      'البحث في المحتوى المحلي الموثق',
    ),
    _ => throw ArgumentError.value(toolId, 'toolId'),
  };
  return intelligenceTextFor(locale, labels.$1, labels.$2);
}

const coachHealthToolProtocol = '''
Additional local health tools (one explicit user intent per action):
close_day {"date":"YYYY-MM-DD"}; reopen_day {"date":"YYYY-MM-DD"};
log_sleep {"date":"YYYY-MM-DD","hours":number 0..14};
save_day_note {"date":"YYYY-MM-DD","text":string max1000};
save_life_context {"date":"YYYY-MM-DD","type":"travel|illness|medicationChange|menstrualContext|stress|event|poorSleep|stoppedTraining|fasting|ramadan|highSodiumMeal|other","text":string max1000,"useInInsights"?:boolean defaultfalse};
start_fasting {"targetHours":integer 1..23}; stop_fasting {};
adjust_fasting {"targetHours"?:integer 1..23,"startedAt"?:ISO8601 with explicit Z/offset}, at least one correction;
log_exercise {"date":"YYYY-MM-DD","workoutId":"walk|run|cycle|strength|upper|lower|mobility|stretch|swim|hike|stairs|row|dance|core|circuit|yoga|pilates|breathing","minutes":integer 5..120};
activate_plan {"pathwayId":exact app catalog ID}; preview_plan {"pathwayId":exact app catalog ID};
read_fasting {};
read_health_history {"topic":"daily|sleep|activity|weight|measurements","from":"YYYY-MM-DD","through":"YYYY-MM-DD","limit"?:integer 1..31};
read_health_progress {"from":"YYYY-MM-DD","through":"YYYY-MM-DD","limit"?:integer 1..31};
search_health_content {"question":string max160,"limit"?:integer 1..3}.
History windows must span at most 31 inclusive civil days. Unknown values are null, never zero.
Write dates cannot be future dates. Propose exercise logging only for an exercise the user says they performed; suggestions are content only.
Every health write requires fresh in-app human review. Plan preview never activates; only explicit activation uses the app's current entitlement and safety gates. Never assert clinician review or insight consent on behalf of the user. Device notifications are a separate result from durable fasting data.
''';

const coachHealthWriteToolIds = {
  'close_day',
  'reopen_day',
  'log_sleep',
  'save_day_note',
  'save_life_context',
  'start_fasting',
  'stop_fasting',
  'adjust_fasting',
  'log_exercise',
  'activate_plan',
};

const coachHealthReadToolIds = {
  'read_health_history',
  'read_health_progress',
  'read_fasting',
  'preview_plan',
  'search_health_content',
};

/// Each descriptor is admitted by the same app-owned action identity boundary
/// as existing native commands. No model output bypasses argument validation.
final class CoachHealthToolDescriptor extends BilToolDescriptor {
  const CoachHealthToolDescriptor({
    required super.name,
    required super.requiredArguments,
    required super.allowedArguments,
    bool readOnly = false,
    bool sensitive = false,
    bool verified = false,
  }) : super(
         type: readOnly
             ? IntelligenceActionType.readHealthData
             : IntelligenceActionType.healthCommand,
         risk: readOnly
             ? BilToolRisk.readOnly
             : sensitive
             ? BilToolRisk.sensitive
             : BilToolRisk.reversibleWrite,
         trustBoundary: verified
             ? BilToolTrustBoundary.serverVerified
             : BilToolTrustBoundary.trustedLocalRepository,
       );

  @override
  Map<String, Object?>? validateArguments(Map<String, Object?> raw) {
    if (!raw.keys.every(allowedArguments.contains) ||
        !requiredArguments.every(raw.containsKey)) {
      return null;
    }
    bool text(String key, int max) =>
        raw[key] is String &&
        (raw[key]! as String).trim().isNotEmpty &&
        (raw[key]! as String).length <= max;
    bool number(String key, num min, num max, {bool integer = false}) {
      final value = raw[key];
      return value is num &&
          (!integer || value is int) &&
          value.isFinite &&
          value >= min &&
          value <= max;
    }

    try {
      if (raw.containsKey('date')) parseHealthDay(raw['date']);
      switch (name) {
        case 'log_sleep':
          if (!number('hours', 0, 14)) return null;
        case 'save_day_note':
          if (!text('text', 1000)) return null;
        case 'save_life_context':
          if (!text('text', 1000) ||
              raw.containsKey('useInInsights') &&
                  raw['useInInsights'] is! bool ||
              !const {
                'travel',
                'illness',
                'medicationChange',
                'menstrualContext',
                'stress',
                'event',
                'poorSleep',
                'stoppedTraining',
                'fasting',
                'ramadan',
                'highSodiumMeal',
                'other',
              }.contains(raw['type'])) {
            return null;
          }
        case 'start_fasting':
          if (!number('targetHours', 1, 23, integer: true)) return null;
        case 'adjust_fasting':
          if (!raw.containsKey('targetHours') &&
              !raw.containsKey('startedAt')) {
            return null;
          }
          if (raw.containsKey('targetHours') &&
              !number('targetHours', 1, 23, integer: true)) {
            return null;
          }
          if (raw.containsKey('startedAt')) {
            final stamp = raw['startedAt'];
            if (stamp is! String ||
                !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(stamp) ||
                DateTime.tryParse(stamp) == null) {
              return null;
            }
          }
        case 'log_exercise':
          if (!text('workoutId', 128) ||
              !number('minutes', 5, 120, integer: true)) {
            return null;
          }
        case 'activate_plan':
        case 'preview_plan':
          if (!text('pathwayId', 80)) return null;
          if (raw.containsKey('clinicianReviewConfirmed') &&
              raw['clinicianReviewConfirmed'] is! bool) {
            return null;
          }
        case 'read_health_history':
        case 'read_health_progress':
          final from = parseHealthDay(raw['from']);
          final through = parseHealthDay(raw['through']);
          // Civil-date ordinals avoid a 23/25-hour DST day changing the bound.
          final span = DateTime.utc(
            through.year,
            through.month,
            through.day,
          ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
          if (span < 0 || span >= 31) return null;
          if (raw.containsKey('limit') &&
              !number('limit', 1, 31, integer: true)) {
            return null;
          }
          if (name == 'read_health_history' &&
              !const {
                'daily',
                'sleep',
                'activity',
                'weight',
                'measurements',
              }.contains(raw['topic'])) {
            return null;
          }
        case 'search_health_content':
          if (!text('question', 160)) return null;
          if (raw.containsKey('limit') &&
              !number('limit', 1, 3, integer: true)) {
            return null;
          }
      }
    } on Object {
      return null;
    }
    return Map<String, Object?>.unmodifiable({
      ...raw,
      if (name == 'save_life_context')
        'useInInsights': raw['useInInsights'] ?? false,
    });
  }
}

const coachHealthToolsByName = <String, BilToolDescriptor>{
  'close_day': CoachHealthToolDescriptor(
    name: 'close_day',
    requiredArguments: {'date'},
    allowedArguments: {'date'},
  ),
  'reopen_day': CoachHealthToolDescriptor(
    name: 'reopen_day',
    requiredArguments: {'date'},
    allowedArguments: {'date'},
  ),
  'log_sleep': CoachHealthToolDescriptor(
    name: 'log_sleep',
    requiredArguments: {'date', 'hours'},
    allowedArguments: {'date', 'hours'},
  ),
  'save_day_note': CoachHealthToolDescriptor(
    name: 'save_day_note',
    requiredArguments: {'date', 'text'},
    allowedArguments: {'date', 'text'},
  ),
  'save_life_context': CoachHealthToolDescriptor(
    name: 'save_life_context',
    sensitive: true,
    requiredArguments: {'date', 'type', 'text'},
    allowedArguments: {'date', 'type', 'text', 'useInInsights'},
  ),
  'start_fasting': CoachHealthToolDescriptor(
    name: 'start_fasting',
    requiredArguments: {'targetHours'},
    allowedArguments: {'targetHours'},
  ),
  'stop_fasting': CoachHealthToolDescriptor(
    name: 'stop_fasting',
    requiredArguments: {},
    allowedArguments: {},
  ),
  'adjust_fasting': CoachHealthToolDescriptor(
    name: 'adjust_fasting',
    requiredArguments: {},
    allowedArguments: {'targetHours', 'startedAt'},
  ),
  'log_exercise': CoachHealthToolDescriptor(
    name: 'log_exercise',
    requiredArguments: {'date', 'workoutId', 'minutes'},
    allowedArguments: {'date', 'workoutId', 'minutes'},
  ),
  'activate_plan': CoachHealthToolDescriptor(
    name: 'activate_plan',
    sensitive: true,
    verified: true,
    requiredArguments: {'pathwayId'},
    allowedArguments: {'pathwayId', 'clinicianReviewConfirmed'},
  ),
  'read_health_history': CoachHealthToolDescriptor(
    name: 'read_health_history',
    readOnly: true,
    requiredArguments: {'topic', 'from', 'through'},
    allowedArguments: {'topic', 'from', 'through', 'limit'},
  ),
  'read_health_progress': CoachHealthToolDescriptor(
    name: 'read_health_progress',
    readOnly: true,
    requiredArguments: {'from', 'through'},
    allowedArguments: {'from', 'through', 'limit'},
  ),
  'read_fasting': CoachHealthToolDescriptor(
    name: 'read_fasting',
    readOnly: true,
    requiredArguments: {},
    allowedArguments: {},
  ),
  'preview_plan': CoachHealthToolDescriptor(
    name: 'preview_plan',
    readOnly: true,
    requiredArguments: {'pathwayId'},
    allowedArguments: {'pathwayId'},
  ),
  'search_health_content': CoachHealthToolDescriptor(
    name: 'search_health_content',
    readOnly: true,
    requiredArguments: {'question'},
    allowedArguments: {'question', 'limit'},
  ),
};
