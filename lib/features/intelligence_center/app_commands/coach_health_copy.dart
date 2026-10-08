import '../intelligence_locale_copy.dart';
import 'coach_activity_catalog.dart';

/// Human-readable, bounded readback copy. Private transaction snapshots never
/// enter this formatter; callers supply only an adapter's receipt projection.
final class CoachHealthCopy {
  const CoachHealthCopy(this.locale);
  final String locale;

  String tr(String en, String ar) => intelligenceTextFor(locale, en, ar);
  String value(Object? raw, {String suffix = ''}) => raw == null
      ? tr('not recorded', 'غير مسجل')
      : '${raw is num ? _number(raw) : raw}$suffix';
  String _number(num raw) => raw == raw.roundToDouble()
      ? raw.toInt().toString()
      : raw.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

  String review(
    String toolId,
    Map<String, Object?> resolved,
    Map<String, Object?> before,
  ) {
    final day = resolved['date'] ?? before['date'];
    final introduction = switch (toolId) {
      'close_day' => tr(
        'Close $day with its recorded nutrition totals? Food changes will require reopening this day.',
        'إغلاق يوم $day بمجاميع التغذية المسجلة؟ ستحتاج إلى إعادة فتح اليوم لتعديل الطعام.',
      ),
      'reopen_day' => tr(
        'Reopen $day so its records can be edited?',
        'إعادة فتح يوم $day للسماح بتعديل سجلاته؟',
      ),
      'log_sleep' => tr(
        'Save ${value(resolved['hours'])} hours of manually recorded sleep for $day? Previous value: ${value(before['sleep_hours'])}.',
        'حفظ ${value(resolved['hours'])} ساعات نوم مسجلة يدويًا ليوم $day؟ القيمة السابقة: ${value(before['sleep_hours'])}.',
      ),
      'save_day_note' => tr(
        'Replace the private note for $day with:\n${resolved['text']}\n\nPrevious note: ${value(before['note'])}.',
        'استبدال الملاحظة الخاصة بيوم $day بالنص:\n${resolved['text']}\n\nالملاحظة السابقة: ${value(before['note'])}.',
      ),
      'save_life_context' => tr(
        'Save this life-context entry for ${resolved['occurredAt'].toString().split('T').first}?\n${resolved['text']}\n\nUse in insights: ${resolved['useInInsights'] == true ? 'yes' : 'no'}. This is separate from Coach memory.',
        'حفظ هذا السياق الحياتي لتاريخ ${resolved['occurredAt'].toString().split('T').first}؟\n${resolved['text']}\n\nالاستخدام في الرؤى: ${resolved['useInInsights'] == true ? 'نعم' : 'لا'}. هذا السجل منفصل عن ذاكرة المدرب.',
      ),
      'start_fasting' => tr(
        'Start a ${resolved['targetHours']}-hour fasting session at ${resolved['startedAtUtc']}? Your existing notification setting will be used.',
        'بدء جلسة صيام لمدة ${resolved['targetHours']} ساعة عند ${resolved['startedAtUtc']}؟ سيُستخدم إعداد الإشعارات الحالي.',
      ),
      'stop_fasting' => tr(
        'Stop the fasting session that began at ${resolved['startedAtUtc']} and save it in fasting history?',
        'إنهاء جلسة الصيام التي بدأت عند ${resolved['startedAtUtc']} وحفظها في سجل الصيام؟',
      ),
      'adjust_fasting' => tr(
        'Correct the active fasting session to start at ${resolved['startedAtUtc']} with a ${resolved['targetHours']}-hour target?',
        'تصحيح بداية جلسة الصيام الحالية إلى ${resolved['startedAtUtc']} والمدة المستهدفة إلى ${resolved['targetHours']} ساعة؟',
      ),
      'log_exercise' => tr(
        'Record ${resolved['minutes']} minutes of ${resolved['name'] ?? resolved['workoutId']} for $day as an exercise you performed? This will not increase your calorie budget.',
        'تسجيل ${resolved['minutes']} دقيقة من ${resolved['nameAr'] ?? resolved['name'] ?? resolved['workoutId']} ليوم $day كتمرين أديته؟ لن يزيد ذلك ميزانية السعرات.',
      ),
      'activate_plan' => tr(
        'Activate ${before['name']} (${resolved['pathwayId']})? This replaces the active program and its weekly nutrition targets after the app verifies access.\n\nProposed targets:\n${_week(before['draftWeekTargets'])}',
        'تفعيل ${before['nameAr']} (${resolved['pathwayId']})؟ سيستبدل ذلك البرنامج النشط وأهداف التغذية الأسبوعية بعد تحقق التطبيق من صلاحية الوصول.\n\nالأهداف المقترحة:\n${_week(before['draftWeekTargets'])}',
      ),
      _ => throw ArgumentError.value(toolId, 'toolId'),
    };
    return '$introduction\n\n${tr('Nothing is saved until you confirm. You can undo a verified save while its records remain unchanged.', 'لن يُحفظ شيء قبل التأكيد. يمكنك التراجع عن الحفظ الموثق ما دامت سجلاته لم تتغير.')}';
  }

  String saved(String toolId, Map<String, Object?> receipt) => switch (toolId) {
    'close_day' => tr(
      'Closed ${receipt['date']}. Calories: ${value(receipt['calories'])}; protein: ${value(receipt['protein'], suffix: ' g')}. Missing nutrients remain unrecorded.',
      'أُغلق يوم ${receipt['date']}. السعرات: ${value(receipt['calories'])}؛ البروتين: ${value(receipt['protein'], suffix: ' غ')}. المغذيات المفقودة تبقى غير مسجلة.',
    ),
    'reopen_day' => tr(
      'Reopened ${receipt['date']}.',
      'أُعيد فتح يوم ${receipt['date']}.',
    ),
    'log_sleep' => tr(
      'Saved ${value(receipt['sleep_hours'])} hours of manual sleep for ${receipt['date']}.',
      'حُفظت ${value(receipt['sleep_hours'])} ساعات نوم يدويًا ليوم ${receipt['date']}.',
    ),
    'save_day_note' => tr(
      'Saved the private note for ${receipt['date']}.',
      'حُفظت الملاحظة الخاصة بيوم ${receipt['date']}.',
    ),
    'save_life_context' => tr(
      'Saved the life-context entry for ${receipt['date']}. Use in insights: ${receipt['use_in_insights'] == true ? 'yes' : 'no'}.',
      'حُفظ السياق الحياتي لتاريخ ${receipt['date']}. الاستخدام في الرؤى: ${receipt['use_in_insights'] == true ? 'نعم' : 'لا'}.',
    ),
    'start_fasting' || 'adjust_fasting' => tr(
      'Fasting session saved: started ${receipt['startedAtUtc']}; target ${receipt['targetHours']} hours.',
      'حُفظت جلسة الصيام: البداية ${receipt['startedAtUtc']}؛ المدة المستهدفة ${receipt['targetHours']} ساعة.',
    ),
    'stop_fasting' => tr(
      'Fasting stopped and saved in history. Duration: ${value(receipt['lastMinutes'], suffix: ' min')}.',
      'أُوقف الصيام وحُفظ في السجل. المدة: ${value(receipt['lastMinutes'], suffix: ' دقيقة')}.',
    ),
    'log_exercise' => tr(
      'Recorded ${receipt['minutes']} minutes of ${_workout(receipt['workoutId'], receipt['name'])} for ${receipt['date']}. Your calorie budget is unchanged.',
      'سُجلت ${receipt['minutes']} دقيقة من ${_workout(receipt['workoutId'], receipt['name'])} ليوم ${receipt['date']}. بقيت ميزانية السعرات كما هي.',
    ),
    'activate_plan' => tr(
      'Activated ${receipt['name']}. Verified weekly targets:\n${_week(receipt['effectiveWeekTargets'])}',
      'فُعّلت خطة ${receipt['nameAr']}. الأهداف الأسبوعية الموثقة:\n${_week(receipt['effectiveWeekTargets'])}',
    ),
    _ => throw ArgumentError.value(toolId, 'toolId'),
  };

  String read(String toolId, Map<String, Object?> result) {
    if (toolId == 'preview_plan') {
      return tr(
        'Preview: ${result['name']} (${result['pathwayId']}). No plan was activated and no targets changed.\nAccess: ${_access(result['access'])}; safety requirement: ${_safety(result['safety'])}.\nDraft targets:\n${_week(result['draftWeekTargets'])}',
        'معاينة: ${result['nameAr']} (${result['pathwayId']}). لم تُفعّل خطة ولم تتغير الأهداف.\nالوصول: ${_access(result['access'])}؛ متطلب السلامة: ${_safety(result['safety'])}.\nأهداف المسودة:\n${_week(result['draftWeekTargets'])}',
      );
    }
    if (toolId == 'read_fasting') {
      if (result['sessionAvailable'] != true) {
        return tr(
          'The saved fasting session could not be verified.',
          'تعذر التحقق من جلسة الصيام المحفوظة.',
        );
      }
      final active = result['active'] == true;
      return active
          ? tr(
              'Active fasting session: started ${result['startedAtUtc']}, target ${result['targetHours']} hours. Completed sessions: ${value(result['historyCount'])}.',
              'جلسة صيام نشطة: البداية ${result['startedAtUtc']}، الهدف ${result['targetHours']} ساعة. الجلسات المكتملة: ${value(result['historyCount'])}.',
            )
          : tr(
              'No active fasting session. Completed sessions: ${value(result['historyCount'])}. Last duration: ${value(result['lastMinutes'], suffix: ' min')}.',
              'لا توجد جلسة صيام نشطة. الجلسات المكتملة: ${value(result['historyCount'])}. آخر مدة: ${value(result['lastMinutes'], suffix: ' دقيقة')}.',
            );
    }
    if (toolId == 'search_health_content') {
      return result['text']?.toString().trim().isNotEmpty == true
          ? result['text']!.toString()
          : tr(
              'No matching verified local content was found.',
              'لم يُعثر على محتوى محلي موثق يطابق الطلب.',
            );
    }
    final rows = (result['rows'] as List).cast<Map>();
    final topic = result['topic'];
    final lines = <String>[
      tr(
        'Recorded data: ${result['from']} to ${result['through']} (${result['queriedDays']} days).',
        'البيانات المسجلة: من ${result['from']} إلى ${result['through']} (${result['queriedDays']} أيام).',
      ),
      if (rows.isEmpty)
        tr('No records in this period.', 'لا توجد سجلات في هذه الفترة.'),
    ];
    for (final row in rows) {
      final data = switch (topic) {
        'daily' => tr(
          'calories ${value(row['caloriesKcal'])}, protein ${value(row['proteinG'], suffix: ' g')}, carbs ${value(row['carbohydratesG'], suffix: ' g')}, fat ${value(row['fatG'], suffix: ' g')}; ${_state(row['state'])}',
          'السعرات ${value(row['caloriesKcal'])}، البروتين ${value(row['proteinG'], suffix: ' غ')}، الكربوهيدرات ${value(row['carbohydratesG'], suffix: ' غ')}، الدهون ${value(row['fatG'], suffix: ' غ')}؛ ${_state(row['state'])}',
        ),
        'weight' ||
        'progress' => value(row['weightKg'], suffix: tr(' kg', ' كغ')),
        'measurements' => tr(
          'waist ${value(row['waistCm'], suffix: ' cm')}, hips ${value(row['hipsCm'], suffix: ' cm')}, neck ${value(row['neckCm'], suffix: ' cm')}, chest ${value(row['chestCm'], suffix: ' cm')}, arm ${value(row['armCm'], suffix: ' cm')}, thigh ${value(row['thighCm'], suffix: ' cm')}',
          'الخصر ${value(row['waistCm'], suffix: ' سم')}، الورك ${value(row['hipsCm'], suffix: ' سم')}، الرقبة ${value(row['neckCm'], suffix: ' سم')}، الصدر ${value(row['chestCm'], suffix: ' سم')}، الذراع ${value(row['armCm'], suffix: ' سم')}، الفخذ ${value(row['thighCm'], suffix: ' سم')}',
        ),
        'sleep' => tr(
          'manual sleep ${value((row['manual'] as Map?)?['hours'], suffix: ' h')}',
          'النوم اليدوي ${value((row['manual'] as Map?)?['hours'], suffix: ' ساعة')}',
        ),
        'activity' => _activity(row),
        _ => '',
      };
      lines.add('${row['day']}: $data');
    }
    final missing = (result['missingDays'] as List).length;
    lines.add(
      tr(
        '$missing days have no record. Missing values are not zero.',
        '$missing أيام بلا سجل. القيم المفقودة ليست صفرًا.',
      ),
    );
    if (result['truncated'] == true) {
      lines.add(
        tr(
          'Showing the newest ${rows.length} recorded days.',
          'تُعرض أحدث ${rows.length} أيام مسجلة.',
        ),
      );
    }
    if (topic == 'sleep' || topic == 'activity') {
      lines.add(
        tr(
          'This answer uses manual records; device health data was not requested. Manual sleep has no saved start/end time.',
          'تستخدم هذه الإجابة السجلات اليدوية؛ لم تُطلب بيانات الصحة من الجهاز. لا يحتوي النوم اليدوي على وقت بداية ونهاية محفوظ.',
        ),
      );
    }
    if (result['analysis'] case final Map analysis) {
      lines.add(
        analysis['confidence'] == 'insufficient'
            ? tr(
                'There is not enough comparable weight evidence for a trend.',
                'لا توجد قياسات وزن قابلة للمقارنة تكفي لتقدير اتجاه.',
              )
            : tr(
                'Weight trend: ${value(analysis['weeklyDirectionKg'], suffix: ' kg/week')} across ${analysis['sampleCount']} readings. Confidence: ${_confidence(analysis['confidence'])}. This does not measure fat or muscle.',
                'اتجاه الوزن: ${value(analysis['weeklyDirectionKg'], suffix: ' كغ/أسبوع')} عبر ${analysis['sampleCount']} قياسات. الثقة: ${_confidence(analysis['confidence'])}. لا يقيس ذلك الدهون أو العضلات.',
              ),
      );
    }
    return lines.join('\n');
  }

  String _activity(Map row) {
    final exercises = (row['exercises'] as List? ?? const []).cast<Map>();
    return [
      tr(
        'manual steps ${value((row['manualSteps'] as Map?)?['count'])}',
        'الخطوات اليدوية ${value((row['manualSteps'] as Map?)?['count'])}',
      ),
      for (final exercise in exercises)
        '${_workout(exercise['id'], exercise['name'])}: ${value(exercise['minutes'], suffix: tr(' min', ' دقيقة'))}',
      if (row['exerciseRecordsTruncated'] == true)
        tr(
          'Additional exercise records omitted by the limit.',
          'حُجبت سجلات تمرين إضافية بسبب حد العرض.',
        ),
    ].join('; ');
  }

  String _state(Object? value) => switch (value) {
    'closed' => tr('closed', 'مغلق'),
    'open' => tr('open', 'مفتوح'),
    'notStarted' => tr('not started', 'لم يبدأ'),
    _ => tr('unavailable', 'غير متاح'),
  };
  String _access(Object? value) => value == 'free'
      ? tr('free', 'مجاني')
      : tr('verified program access required', 'تتطلب صلاحية موثقة للبرامج');
  String _safety(Object? value) => switch (value) {
    'standard' => tr('standard program', 'برنامج عام'),
    'clinicianReview' => tr(
      'clinician review required',
      'تتطلب مراجعة مختص صحي',
    ),
    'medicalSupervision' => tr(
      'medical supervision required',
      'تتطلب إشرافًا طبيًا',
    ),
    _ => tr('unavailable', 'غير متاح'),
  };
  String _confidence(Object? value) => switch (value) {
    'high' => tr('high', 'مرتفعة'),
    'medium' || 'moderate' => tr('moderate', 'متوسطة'),
    'low' => tr('low', 'منخفضة'),
    'insufficient' => tr('insufficient', 'غير كافية'),
    _ => tr('unavailable', 'غير متاحة'),
  };
  String _workout(Object? id, Object? fallback) {
    for (final entry in coachActivityCatalog) {
      if (entry.id == id) return tr(entry.name, entry.nameAr);
    }
    return fallback?.toString() ?? tr('recorded exercise', 'تمرين مسجل');
  }

  String _week(Object? raw) {
    if (raw is! Map) return tr('not recorded', 'غير مسجل');
    const en = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const ar = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return [
      for (var day = 1; day <= 7; day++)
        if (raw['$day'] case final Map targets)
          '${tr(en[day - 1], ar[day - 1])}: ${value(targets['caloriesKcal'], suffix: tr(' kcal', ' سعرة'))}; ${tr('protein', 'البروتين')} ${value(targets['proteinG'], suffix: tr(' g', ' غ'))}; ${tr('carbs', 'الكربوهيدرات')} ${value(targets['carbsG'], suffix: tr(' g', ' غ'))}; ${tr('fat', 'الدهون')} ${value(targets['fatG'], suffix: tr(' g', ' غ'))}',
    ].join('\n');
  }
}
