/// Arabic rendering of the pinned BIL source phases, preserving its numbers
/// and conditional wording. This is localization, not model-written advice.
String smartPlanSourcePhaseText(String english, String locale) {
  if (locale != 'ar') return english;
  return const {
        'Technique foundation': 'تأسيس التقنية',
        'Base volume': 'الحجم الأساسي',
        'PPL A/B introduction': 'التدرج إلى الدفع والسحب والرجلين A/B',
        'Hypertrophy PPL': 'الدفع والسحب والرجلين لتنمية العضلات',
        'Strength-hypertrophy PPL':
            'الدفع والسحب والرجلين للقوة وتنمية العضلات',
        'PPL specialization and consolidation':
            'تخصيص وتثبيت الدفع والسحب والرجلين',
        'Keep 2-4 good repetitions in reserve; learn stable setup and range.':
            'اترك 2–4 تكرارات جيدة احتياطية، وتعلّم وضعية ثابتة ومدى حركة مناسبًا.',
        'Week 4: reduce working sets by about one third.':
            'الأسبوع 4: خفّض مجموعات العمل بنحو الثلث.',
        'Add repetitions inside the range before adding a small load.':
            'زِد التكرارات ضمن المدى قبل إضافة حمل صغير.',
        'Week 8: reduce sets and keep all repetitions comfortably controlled.':
            'الأسبوع 8: خفّض المجموعات وحافظ على التحكم المريح في كل التكرارات.',
        'Continue the rotation across calendar weeks; never cram missed sessions.':
            'واصل تناوب الجلسات عبر الأسابيع، ولا تضغط الجلسات الفائتة في وقت قصير.',
        'Final week: one A session per pattern only.':
            'الأسبوع الأخير: جلسة A واحدة لكل نمط فقط.',
        'Most work uses 8-15 reps with 1-3 repetitions in reserve.':
            'معظم العمل من 8–15 تكرارًا، مع إبقاء 1–3 تكرارات احتياطية.',
        'Final 5-7 days: half the accessory sets.':
            'آخر 5–7 أيام: نصف مجموعات التمارين المساعدة.',
        'Primary lifts use the lower end of their range; accessories stay controlled.':
            'تستخدم الحركات الأساسية الحد الأدنى من مداها، وتبقى الحركات المساعدة تحت التحكم.',
        'Final week: no grinding repetitions and reduce primary load.':
            'الأسبوع الأخير: تجنّب التكرارات المجهدة جدًا وخفّض الحمل الأساسي.',
        'Choose one lagging pattern for one extra accessory set, not every pattern.':
            'اختر نمطًا واحدًا يحتاج تحسينًا لإضافة مجموعة مساعدة واحدة، وليس لكل الأنماط.',
        'Week 24: technique-only sessions, then restart with updated loads.':
            'الأسبوع 24: جلسات للتقنية فقط، ثم ابدأ مجددًا بأحمال محدثة.',
      }[english] ??
      english;
}
