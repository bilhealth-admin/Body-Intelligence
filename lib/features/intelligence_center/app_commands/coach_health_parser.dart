import '../../../data/database/date_keys.dart';
import '../../nutrition_plans/domain/nutrition_pathway_access_policy.dart';
import '../domain/bil_tool_registry.dart';
import '../domain/intelligence_action.dart';
import '../services/coach_date_resolver.dart';
import 'coach_activity_catalog.dart';

/// Explicit offline commands produce reviewable proposals only. The whole
/// command header must match one supported intent, one amount and one civil day.
/// Note and content-search bodies are literal text, never another instruction.
final class LocalCoachHealthCommandParser {
  const LocalCoachHealthCommandParser({
    this.dateResolver = const CoachDateResolver(),
  });

  final CoachDateResolver dateResolver;

  /// A routing hint for local clarification when [parse] returns null. This
  /// deliberately recognizes negated/ambiguous health requests without
  /// admitting them as actions, so they cannot fall through to a remote parser.
  /// Unrelated food, calorie, water, weight-write and navigation intents retain
  /// their existing parser.
  bool recognizesHealthIntent(String input) {
    final separator = input.indexOf(':');
    final header = _normalize(
      separator < 0 ? input : input.substring(0, separator),
    );
    final dated = _dated(header, DateTime(2000, 1, 1));
    if (dated?.specifiedDate == true &&
        _matches(dated!.command, r'قفل|اقفل|اغلق|افتح|اعد فتح')) {
      return true;
    }
    return RegExp(
      r"(?:^|[\s,،])(?:"
      r"(?:close|lock|reopen|unlock) (?:my |the )?day|"
      r"(?:start|stop|end|adjust|change|show) (?:my )?fast(?:ing)?|"
      r"fasting status|i slept|slept|(?:log|record) sleep|"
      r"(?:save|log) (?:a )?note|(?:save|log) life context|"
      r"(?:log|record) (?:a )?(?:workout|exercise)|"
      r"i (?:trained|walked|ran|swam|cycled)|"
      r"(?:preview|show|activate|start) plan|"
      r"(?:find|search) health content|"
      r"(?:show|read|view) (?:my )?(?:sleep|activity|exercise|workout|"
      r"weight|measurements|progress|nutrition|daily)|"
      r"(?:قفل|اقفل|اغلق|افتح|اعد فتح) (?:يومي|اليوم)|"
      r"(?:ابدا|ابدء|بدا|اوقف|انهي|انه|عدل|اعرض) الصيام|"
      r"غير مدة الصيام|حالة الصيام|نمت|"
      r"(?:سجل|تسجل) (?:نوم|النوم|تمرين|ملاحظة|سياق حياتي)|"
      r"احفظ (?:ملاحظة|سياق حياتي)|تمرنت|مشيت|ركضت|"
      r"(?:عاين|اعرض|فعل|ابدا) خطة|ابحث في المحتوى|"
      r"(?:اعرض|اقرا) (?:النوم|نوم|سجل النوم|النشاط|التمارين|"
      r"الوزن|وزني|القياسات|قياساتي|التقدم|تقدمي|التغذية|ملخص)"
      r")(?:$|[\s:,.!?؟،])",
    ).hasMatch(header);
  }

  IntelligenceAction? parse(
    String input, {
    required String locale,
    required DateTime referenceLocal,
  }) {
    if (input.trim().isEmpty || input.length > 1600) return null;
    final ar = locale.toLowerCase().startsWith('ar');
    final reference = referenceLocal.toLocal();
    final today = DateTime(reference.year, reference.month, reference.day);

    IntelligenceAction? action(
      String tool,
      Map<String, Object?> arguments,
      String en,
      String arabic,
    ) => const BilToolRegistry().createAction(
      name: tool,
      arguments: arguments,
      label: ar ? arabic : en,
    );

    // Only the header chooses an intent/date. Preserve body spelling, digits,
    // punctuation, interior whitespace, newlines and additional colons.
    final separator = input.indexOf(':');
    if (separator >= 0) {
      final header = _dated(input.substring(0, separator), today);
      if (header == null) return null;
      final body = input.substring(separator + 1).trim();
      final day = dayKeyFor(header.date);
      if (_matches(
        header.command,
        r'(?:find|search) health content|ابحث في المحتوى',
      )) {
        if (header.specifiedDate) return null;
        return action(
          'search_health_content',
          {'question': body, 'limit': 3},
          'Find related app health content',
          'البحث في المحتوى الصحي للتطبيق',
        );
      }
      if (header.question || header.date.isAfter(today)) return null;
      if (_matches(
        header.command,
        r'(?:save|log) (?:a )?note|سجل ملاحظة|احفظ ملاحظة',
      )) {
        return action(
          'save_day_note',
          {'date': day, 'text': body},
          'Save the daily note for $day',
          'حفظ ملاحظة يوم $day',
        );
      }
      if (_matches(
        header.command,
        r'(?:save|log) life context|سجل سياق حياتي|احفظ سياق حياتي',
      )) {
        return action(
          'save_life_context',
          {'date': day, 'type': 'other', 'text': body, 'useInInsights': false},
          'Save private life context for $day',
          'حفظ سياق حياتي خاص ليوم $day',
        );
      }
      return null;
    }

    final dated = _dated(input, today);
    if (dated == null || dated.date.isAfter(today)) return null;
    final value = dated.command;
    final day = dayKeyFor(dated.date);
    final canWrite = !dated.question;
    if (canWrite &&
        (_matches(
              value,
              r'(?:close|lock) (?:my |the )?day|(?:قفل|اقفل|اغلق) يومي',
            ) ||
            dated.specifiedDate && _matches(value, r'قفل|اقفل|اغلق'))) {
      return action(
        'close_day',
        {'date': day},
        'Close day $day',
        'قفل يوم $day',
      );
    }
    if (canWrite &&
        (_matches(
              value,
              r'(?:reopen|unlock) (?:my |the )?day|افتح يومي|اعد فتح يومي',
            ) ||
            dated.specifiedDate && _matches(value, r'افتح|اعد فتح'))) {
      return action(
        'reopen_day',
        {'date': day},
        'Reopen day $day',
        'إعادة فتح يوم $day',
      );
    }

    // Start, stop and target adjustment act on the session now. A historical
    // day must never be silently discarded to perform one of these writes.
    if (canWrite && dated.date == today) {
      final start = RegExp(
        r'^(?:start (?:my )?fast(?:ing)?|ابدا الصيام|ابدء الصيام|بدا الصيام)'
        r'\s+(?:(?:for|لمدة)\s+)?(\d+)\s*'
        r'(?:hours?|h|ساعة|ساعه|ساعات)(?:\s+(?:now|الان))?$',
      ).firstMatch(value);
      if (start != null) {
        final hours = int.tryParse(start[1]!);
        return action(
          'start_fasting',
          {'targetHours': hours},
          'Start a $hours-hour fast now',
          'بدء صيام $hours ساعة الآن',
        );
      }
      if (_matches(
        value,
        r'(?:stop|end) (?:my )?fast(?:ing)?(?: now)?|'
        r'(?:اوقف|انهي|انه) الصيام(?: الان)?',
      )) {
        return action(
          'stop_fasting',
          {},
          'End the active fast now',
          'إنهاء الصيام الجاري الآن',
        );
      }
      final adjust = RegExp(
        r'^(?:adjust (?:my )?fast(?:ing)?|change (?:my )?fast(?:ing)?|'
        r'عدل الصيام|غير مدة الصيام)\s+(?:(?:to|for|الى|لمدة)\s+)?'
        r'(\d+)\s*(?:hours?|h|ساعة|ساعه|ساعات)(?:\s+(?:now|الان))?$',
      ).firstMatch(value);
      if (adjust != null) {
        final hours = int.tryParse(adjust[1]!);
        return action(
          'adjust_fasting',
          {'targetHours': hours},
          'Change the active fasting target to $hours hours',
          'تعديل هدف الصيام الجاري إلى $hours ساعة',
        );
      }
    }

    if (canWrite) {
      final sleep = RegExp(
        r'^(?:i slept|slept|log sleep|record sleep|نمت|سجل نوم|سجل النوم)'
        r'\s+(?:(?:for|لمدة)\s+)?(\d+(?:[.,]\d+)?)\s*'
        r'(?:hours?|h|ساعة|ساعه|ساعات)$',
      ).firstMatch(value);
      if (sleep != null) {
        final amount = sleep[1]!;
        // A comma with three or more digits is also a thousands separator.
        // Ask for an unambiguous decimal rather than choosing its meaning.
        if (RegExp(r',\d{3,}$').hasMatch(amount)) return null;
        final hours = double.tryParse(amount.replaceAll(',', '.'));
        return action(
          'log_sleep',
          {'date': day, 'hours': hours},
          'Save $hours hours of manual sleep for $day',
          'حفظ نوم يدوي $hours ساعة ليوم $day',
        );
      }

      var exerciseText = value;
      const firstPerson = {
        'i walked ': 'log exercise walk ',
        'i ran ': 'log exercise run ',
        'i swam ': 'log exercise swim ',
        'i cycled ': 'log exercise cycle ',
        'i trained ': 'log exercise ',
        'مشيت ': 'سجل تمرين مشي ',
        'ركضت ': 'سجل تمرين ركض ',
        'تمرنت ': 'سجل تمرين ',
      };
      for (final entry in firstPerson.entries) {
        if (exerciseText.startsWith(entry.key)) {
          exerciseText = entry.value + exerciseText.substring(entry.key.length);
          break;
        }
      }
      final exercise = RegExp(
        r'^(?:(?:log|record) (?:a )?(?:workout|exercise)|سجل تمرين)\s+'
        r'(.+?)\s+(?:(?:for|لمدة)\s+)?(\d+)\s*'
        r'(?:minutes?|mins?|دقيقة|دقيقه|دقائق)$',
      ).firstMatch(exerciseText);
      if (exercise != null) {
        final movement = exercise[1]!;
        String? workoutId;
        for (final entry in _activityAliases.entries) {
          if (entry.value.contains(movement)) workoutId = entry.key;
        }
        if (coachActivityForExactId(workoutId) == null) return null;
        final minutes = int.tryParse(exercise[2]!);
        return action(
          'log_exercise',
          {'date': day, 'workoutId': workoutId, 'minutes': minutes},
          'Record $workoutId: $minutes minutes on $day',
          'تسجيل $workoutId: $minutes دقيقة في $day',
        );
      }
    }

    final plan = RegExp(
      r'^(preview plan|show plan|عاين خطة|اعرض خطة|'
      r'activate plan|start plan|فعل خطة|ابدا خطة)\s+([a-z][a-z0-9_-]{0,79})$',
    ).firstMatch(value);
    if (plan != null && dated.date == today) {
      final pathwayId = plan[2]!;
      if (nutritionPathwayForExactId(pathwayId) == null) return null;
      final activation = _matches(
        plan[1]!,
        r'activate plan|start plan|فعل خطة|ابدا خطة',
      );
      if (activation && !canWrite) return null;
      // A typed command never manufactures clinician review or entitlement.
      return action(
        activation ? 'activate_plan' : 'preview_plan',
        {'pathwayId': pathwayId},
        activation
            ? 'Activate nutrition plan $pathwayId'
            : 'Preview nutrition plan $pathwayId',
        activation
            ? 'تفعيل خطة التغذية $pathwayId'
            : 'معاينة خطة التغذية $pathwayId',
      );
    }

    if (dated.date == today &&
        _matches(
          value,
          r'show (?:my )?fast(?:ing)?|fasting status|اعرض الصيام|حالة الصيام',
        )) {
      return action(
        'read_fasting',
        {},
        'Read the saved fasting session',
        'قراءة جلسة الصيام المحفوظة',
      );
    }
    final read = RegExp(
      r'^(?:show|read|view|اعرض|اقرا)\s+(?:my\s+)?(.+)$',
    ).firstMatch(value);
    if (read == null) return null;
    var topicText = read[1]!;
    var count = dated.specifiedDate ? 1 : 7;
    final window = RegExp(
      r'^(.*?)\s+(?:(?:for|over|during|the|last|past|خلال|اخر|لمدة)\s+){0,3}'
      r'(\d+)\s*(?:days?|ايام|يوم)$',
    ).firstMatch(topicText);
    if (window != null) {
      topicText = window[1]!;
      final parsed = int.tryParse(window[2]!);
      if (parsed == null) return null;
      count = parsed;
    }
    if (count < 1 || count > 31) return null;
    String? topic;
    for (final entry in _readTopics.entries) {
      if (entry.value.contains(topicText)) topic = entry.key;
    }
    if (topic == null) return null;
    final end = dated.date;
    final from = DateTime(end.year, end.month, end.day - count + 1);
    final fromKey = dayKeyFor(from);
    final throughKey = dayKeyFor(end);
    final topicLabel = _readTopicNames[topic]!;
    return action(
      topic == 'progress' ? 'read_health_progress' : 'read_health_history',
      {
        if (topic != 'progress') 'topic': topic,
        'from': fromKey,
        'through': throughKey,
        'limit': 31,
      },
      'Read saved ${topicLabel.$1}: $fromKey to $throughKey',
      'قراءة سجل ${topicLabel.$2}: $fromKey إلى $throughKey',
    );
  }

  _HealthDatedCommand? _dated(String input, DateTime today) {
    var value = _normalize(input);
    final question = RegExp(r'[?؟]').hasMatch(value);
    value = value.replaceFirst(RegExp(r'[.!?؟]+$'), '').trim();
    value = value.replaceFirst(RegExp(r'^(?:please|من فضلك|لو سمحت)\s+'), '');
    value = value.replaceFirst(RegExp(r'\s+(?:please|من فضلك|لو سمحت)$'), '');
    String? dateText;
    final suffix = RegExp(
      r'\s+(?:(?:on|for|dated|بتاريخ|ليوم|في|يوم)\s+)?(' + _datePattern + r')$',
    ).firstMatch(value);
    if (suffix != null) {
      dateText = suffix[1]!;
      value = value.substring(0, suffix.start).trim();
    } else {
      final prefix = RegExp(
        r'^(?:(?:on|dated|بتاريخ|في|يوم)\s+)?(' +
            _datePattern +
            r')(?:\s*[,،]\s*|\s+)(.+)$',
      ).firstMatch(value);
      if (prefix != null) {
        dateText = prefix[1]!;
        value = prefix[2]!.trim();
      }
    }
    // Never resolve only one of repeated, mixed, malformed or conflicting dates.
    if (dateResolver.hasExplicitDate(value) ||
        RegExp(
          r'(?:^|\s)(?:' + _relativeDatePattern + r')(?:$|\s)',
        ).hasMatch(value)) {
      return null;
    }
    final date = dateText == null
        ? today
        : dateResolver.resolve(dateText, referenceLocal: today);
    if (date == null || value.isEmpty) return null;
    return _HealthDatedCommand(
      command: value,
      date: date,
      specifiedDate: dateText != null,
      question: question,
    );
  }

  static bool _matches(String value, String pattern) => RegExp(
    '^(?:$pattern)'
    r'$',
  ).hasMatch(value);

  static String _normalize(String input) {
    var value = input.trim().toLowerCase();
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const eastern = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < 10; i++) {
      value = value.replaceAll(arabic[i], '$i').replaceAll(eastern[i], '$i');
    }
    return value
        .replaceAll(RegExp(r'[\u0640\u064b-\u065f\u0670]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('٫', '.')
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

final class _HealthDatedCommand {
  const _HealthDatedCommand({
    required this.command,
    required this.date,
    required this.specifiedDate,
    required this.question,
  });

  final String command;
  final DateTime date;
  final bool specifiedDate;
  final bool question;
}

const _relativeDatePattern =
    r'last (?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)|'
    r'(?:a )?week ago|قبل اسبوع|'
    r'الاثنين الماضي|الاتنين اللي فات|الثلاثاء الماضي|التلات اللي فات|'
    r'الاربعاء الماضي|الاربع اللي فات|الخميس الماضي|الخميس اللي فات|'
    r'الجمعة الماضية|الجمعه اللي فاتت|السبت الماضي|السبت اللي فات|'
    r'الاحد الماضي|الاحد اللي فات|يوم الحد|يوم الاحد|عالاحد|'
    r'yesterday|امس|مبارح|today|اليوم|النهارده|النهاردة';

const _monthPattern =
    r'january|jan|يناير|february|feb|فبراير|march|mar|مارس|'
    r'april|apr|ابريل|may|مايو|june|jun|يونيو|july|jul|يوليو|'
    r'august|aug|اغسطس|september|sep|sept|سبتمبر|'
    r'october|oct|اكتوبر|november|nov|نوفمبر|december|dec|ديسمبر';

const _datePattern =
    r'\d{4}[-/]\d{1,2}[-/]\d{1,2}|'
    r'\d{1,2}\s*(?:'
    '$_monthPattern'
    r')\s*,?\s*\d{4}|'
    '$_relativeDatePattern';

const _activityAliases = <String, List<String>>{
  'walk': ['walk', 'walked', 'walking', 'مشي'],
  'run': ['run', 'running', 'ran', 'ركض', 'جري'],
  'cycle': ['cycle', 'cycling', 'دراجة', 'دراجه'],
  'swim': ['swim', 'swimming', 'سباحة', 'سباحه'],
  'strength': ['strength', 'حديد', 'مقاومة', 'مقاومه'],
  'upper': [
    'upper',
    'upper body',
    'upper-body strength',
    'مقاومة الجزء العلوي',
  ],
  'lower': [
    'lower',
    'lower body',
    'lower-body strength',
    'مقاومة الجزء السفلي',
  ],
  'mobility': ['mobility', 'mobility flow', 'تمارين مرونة'],
  'stretch': ['stretch', 'stretching', 'اطالة', 'اطاله'],
  'hike': ['hike', 'hiking', 'المشي الجبلي'],
  'stairs': ['stairs', 'stair climbing', 'صعود الدرج'],
  'row': ['row', 'rowing', 'تجديف', 'التجديف'],
  'dance': ['dance', 'dancing', 'لياقة الرقص'],
  'core': ['core', 'core strength', 'تقوية الجذع'],
  'circuit': ['circuit', 'strength circuit', 'دائرة تمارين المقاومة'],
  'yoga': ['yoga', 'يوغا', 'يوجا'],
  'pilates': ['pilates', 'بيلاتس'],
  'breathing': ['breathing', 'breathing recovery', 'تنفس للتعافي'],
};

const _readTopicNames = <String, (String, String)>{
  'sleep': ('sleep', 'النوم'),
  'activity': ('activity', 'النشاط'),
  'weight': ('weight', 'الوزن'),
  'measurements': ('measurements', 'القياسات'),
  'progress': ('progress', 'التقدم'),
  'daily': ('nutrition', 'التغذية'),
};

const _readTopics = <String, List<String>>{
  'sleep': ['sleep', 'sleep history', 'نوم', 'النوم', 'سجل النوم'],
  'activity': [
    'activity',
    'activity history',
    'exercise',
    'exercise history',
    'workout',
    'workout history',
    'النشاط',
    'التمارين',
  ],
  'weight': ['weight', 'weight history', 'الوزن', 'وزني'],
  'measurements': [
    'measurements',
    'measurement history',
    'القياسات',
    'قياساتي',
  ],
  'progress': ['progress', 'weight progress', 'التقدم', 'تقدمي'],
  'daily': [
    'nutrition',
    'daily nutrition',
    'daily log',
    'التغذية',
    'ملخص',
    'ملخص التغذية',
  ],
};
