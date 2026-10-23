part of 'bil_smart_plan_page.dart';

final class _PlanOptions {
  const _PlanOptions({
    required this.horizon,
    required this.focus,
    required this.workoutsPerWeek,
    required this.diet,
    required this.confirmedPreferences,
    required this.highRiskSymptoms,
    required this.needsMedicalReview,
    required this.setup,
  });
  final BilPlanHorizon horizon;
  final BilPlanFocus focus;
  final int workoutsPerWeek;
  final MealPlanDiet diet;
  final bool confirmedPreferences, highRiskSymptoms, needsMedicalReview;
  final BilPlanSetup? setup;
}

class _PlanCreationSheet extends StatefulWidget {
  const _PlanCreationSheet({
    this.initialHorizon,
    this.initialFocus,
    this.initialSetup,
    this.initialSessionsPerWeek,
  });
  final BilPlanHorizon? initialHorizon;
  final BilPlanFocus? initialFocus;
  final BilPlanSetup? initialSetup;
  final int? initialSessionsPerWeek;

  @override
  State<_PlanCreationSheet> createState() => _PlanCreationSheetState();
}

class _PlanCreationSheetState extends State<_PlanCreationSheet> {
  BilPlanHorizon horizon = BilPlanHorizon.month;
  BilPlanFocus focus = BilPlanFocus.combined;
  MealPlanDiet diet = MealPlanDiet.balanced;
  int sessions = 3;
  bool confirmedPreferences = false;
  bool riskSymptoms = false;
  bool medicalReview = false;
  BilPlanEnvironment environment = BilPlanEnvironment.gym;
  BilPlanExperience? experience;
  int minutes = 30;
  String? preferredTime;
  final equipment = <String>{'none'};

  @override
  void initState() {
    super.initState();
    horizon = widget.initialHorizon ?? BilPlanHorizon.month;
    focus = widget.initialFocus ?? BilPlanFocus.combined;
    final saved = widget.initialSetup;
    if (saved != null) {
      environment = saved.environment;
      experience = saved.experience;
      minutes = saved.sessionMinutes;
      preferredTime = saved.preferredTime;
      if (saved.environment == BilPlanEnvironment.home) {
        equipment
          ..clear()
          ..addAll(saved.equipment);
      }
    }
    final frequency = widget.initialSessionsPerWeek;
    if (frequency != null && frequency >= 1 && frequency <= 6) {
      sessions = frequency;
    }
    if (environment == BilPlanEnvironment.home && sessions > 3) sessions = 3;
    // Every replacement still requires fresh safety and preference confirmation.
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String arabic) => _smartPlanText(context, en, arabic);
    final savedMinutes = widget.initialSetup?.sessionMinutes;
    final minimumMinutes = savedMinutes != null && savedMinutes < 10
        ? savedMinutes.toDouble()
        : 10.0;
    final maximumMinutes = savedMinutes != null && savedMinutes > 90
        ? savedMinutes.toDouble()
        : 90.0;
    final preferredTimes = <String>{
      for (var hour = 0; hour < 24; hour++)
        '${hour.toString().padLeft(2, '0')}:00',
      ?preferredTime,
    }.toList()..sort();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('Create a reviewable plan', 'إنشاء خطة للمراجعة'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<BilPlanHorizon>(
                decoration: InputDecoration(labelText: t('Duration', 'المدة')),
                itemHeight: null,
                isExpanded: true,
                initialValue: horizon,
                items: [
                  for (final item in BilPlanHorizon.values)
                    DropdownMenuItem(
                      value: item,
                      child: Text(switch (item) {
                        BilPlanHorizon.week => t('One week', 'أسبوع'),
                        BilPlanHorizon.month => t('One month', 'شهر'),
                        BilPlanHorizon.threeMonths => t(
                          'Three months',
                          '3 أشهر',
                        ),
                        BilPlanHorizon.sixMonths => t('Six months', '6 أشهر'),
                      }),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => horizon = value ?? horizon),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BilPlanFocus>(
                decoration: InputDecoration(
                  labelText: t('Plan focus', 'تركيز الخطة'),
                ),
                itemHeight: null,
                isExpanded: true,
                initialValue: focus,
                items: [
                  DropdownMenuItem(
                    value: BilPlanFocus.combined,
                    child: Text(t('Training and nutrition', 'تدريب وتغذية')),
                  ),
                  DropdownMenuItem(
                    value: BilPlanFocus.training,
                    child: Text(t('Training only', 'تدريب فقط')),
                  ),
                  DropdownMenuItem(
                    value: BilPlanFocus.nutrition,
                    child: Text(t('Nutrition only', 'تغذية فقط')),
                  ),
                ],
                onChanged: (value) => setState(() => focus = value ?? focus),
              ),
              if (focus != BilPlanFocus.nutrition) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<BilPlanEnvironment>(
                  initialValue: environment,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t('Training environment', 'مكان التدريب'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: BilPlanEnvironment.gym,
                      child: Text(t('Gym', 'النادي')),
                    ),
                    DropdownMenuItem(
                      value: BilPlanEnvironment.home,
                      child: Text(t('Home', 'المنزل')),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    environment = value ?? environment;
                    if (environment == BilPlanEnvironment.home &&
                        sessions > 3) {
                      sessions = 3;
                    }
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BilPlanExperience>(
                  initialValue: experience,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t('Training experience', 'الخبرة التدريبية'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: BilPlanExperience.beginner,
                      child: Text(t('Beginner', 'مبتدئ')),
                    ),
                    DropdownMenuItem(
                      value: BilPlanExperience.regular,
                      child: Text(t('Regular practice', 'ممارسة منتظمة')),
                    ),
                    DropdownMenuItem(
                      value: BilPlanExperience.experienced,
                      child: Text(t('Experienced', 'متمرس')),
                    ),
                  ],
                  onChanged: (value) => setState(() => experience = value),
                ),
                const SizedBox(height: 16),
                Text(
                  '${t('Your session time budget: ', 'الوقت المتاح للجلسة: ')}$minutes${t(' min', ' دقيقة')}',
                ),
                Slider(
                  value: minutes.toDouble(),
                  min: minimumMinutes,
                  max: maximumMinutes,
                  divisions: minimumMinutes == 10 && maximumMinutes == 90
                      ? 16
                      : (maximumMinutes - minimumMinutes).round(),
                  label: '$minutes',
                  onChanged: (value) => setState(() => minutes = value.round()),
                ),
                DropdownButtonFormField<String>(
                  initialValue: preferredTime,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t(
                      'Preferred time (optional)',
                      'الوقت المفضل (اختياري)',
                    ),
                  ),
                  items: [
                    for (final time in preferredTimes)
                      DropdownMenuItem(value: time, child: Text(time)),
                  ],
                  onChanged: (value) => setState(() => preferredTime = value),
                ),
                if (environment == BilPlanEnvironment.home) ...[
                  const SizedBox(height: 16),
                  Text(t('Available equipment', 'المعدات المتاحة')),
                  for (final item in [
                    ('exercise mat', t('Exercise mat', 'بساط تمرين')),
                    ('dumbbell pair', t('Dumbbells', 'أوزان يدوية')),
                    (
                      'long resistance band',
                      t('Resistance band', 'حبل مقاومة'),
                    ),
                    ('kettlebell single', t('Kettlebell', 'كرة حديدية')),
                  ])
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.$2),
                      value: equipment.contains(item.$1),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          equipment.add(item.$1);
                          if (item.$1 == 'dumbbell pair') {
                            equipment.add('dumbbell single');
                          }
                        } else {
                          equipment.remove(item.$1);
                          if (item.$1 == 'dumbbell pair') {
                            equipment.remove('dumbbell single');
                          }
                        }
                      }),
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  t('Sessions per week: ', 'جلسات التدريب أسبوعيًا: ') +
                      sessions.toString(),
                ),
                Slider(
                  value: sessions.toDouble(),
                  min: 1,
                  max: environment == BilPlanEnvironment.home ? 3 : 6,
                  divisions: environment == BilPlanEnvironment.home ? 2 : 5,
                  label: sessions.toString(),
                  onChanged: (value) =>
                      setState(() => sessions = value.round()),
                ),
                Text(
                  environment == BilPlanEnvironment.home
                      ? t(
                          'Source-backed Home strength sessions include warm-up, sets, repetitions and rest. Up to 3 sessions per week leave recovery days. Use stable furniture where required, a clear safe floor, and comfortable resistance. Your chosen time is availability, not a finish deadline.',
                          'جلسات القوة المنزلية موثقة بالإحماء والمجموعات والتكرارات والراحة. حتى 3 جلسات أسبوعيًا مع أيام للتعافي. استخدم أثاثًا ثابتًا عند الحاجة وأرضية آمنة ومقاومة مريحة. الوقت المختار وقت متاح وليس مهلة للإكمال.',
                        )
                      : t(
                          'Uses the released BIL Gym plan with its source warm-up, sets, repetitions and rest. Review the draft before activating it.',
                          'يستخدم خطة النادي المعتمدة في BIL مع الإحماء والمجموعات والتكرارات والراحة من مصدرها. راجع المسودة قبل تفعيلها.',
                        ),
                ),
                const SizedBox(height: 16),
              ],
              if (focus != BilPlanFocus.training)
                DropdownButtonFormField<MealPlanDiet>(
                  decoration: InputDecoration(
                    labelText: t('Recipe style', 'نمط الوجبات'),
                  ),
                  itemHeight: null,
                  isExpanded: true,
                  initialValue: diet,
                  items: [
                    DropdownMenuItem(
                      value: MealPlanDiet.balanced,
                      child: Text(t('Balanced recipes', 'وجبات متوازنة')),
                    ),
                    DropdownMenuItem(
                      value: MealPlanDiet.vegetarian,
                      child: Text(t('Vegetarian recipes', 'وجبات نباتية')),
                    ),
                    DropdownMenuItem(
                      value: MealPlanDiet.highProtein,
                      child: Text(
                        t('High-protein recipes', 'وجبات عالية البروتين'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => diet = value ?? diet),
                ),
              CheckboxListTile(
                value: confirmedPreferences,
                onChanged: (value) =>
                    setState(() => confirmedPreferences = value ?? false),
                title: Text(
                  t(
                    'I am 18 or older and reviewed my allergies, dietary restrictions and training availability.',
                    'عمري 18 عامًا أو أكثر وراجعت قيود الطعام والحساسية وتوفر التدريب.',
                  ),
                ),
              ),
              CheckboxListTile(
                value: riskSymptoms,
                onChanged: (value) =>
                    setState(() => riskSymptoms = value ?? false),
                title: Text(
                  t(
                    'I have concerning symptoms or an injury affecting exercise.',
                    'لدي أعراض مقلقة أو إصابة تؤثر على التمرين.',
                  ),
                ),
              ),
              CheckboxListTile(
                value: medicalReview,
                onChanged: (value) =>
                    setState(() => medicalReview = value ?? false),
                title: Text(
                  t(
                    'I am pregnant, postpartum, or my diet or training requires clinician supervision.',
                    'أنا حامل أو بعد الولادة، أو يحتاج غذائي أو تدريبي متابعة طبية.',
                  ),
                ),
              ),
              if (riskSymptoms || medicalReview)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    t(
                      'A qualified professional should review your needs before a personal plan is prepared.',
                      'راجع مختصًا لتقييم احتياجاتك قبل إعداد خطة شخصية.',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('bil-smart-plan-review-draft'),
                onPressed:
                    confirmedPreferences &&
                        !riskSymptoms &&
                        !medicalReview &&
                        (focus == BilPlanFocus.nutrition || experience != null)
                    ? () => Navigator.pop(
                        context,
                        _PlanOptions(
                          horizon: horizon,
                          focus: focus,
                          workoutsPerWeek: sessions,
                          diet: diet,
                          confirmedPreferences: confirmedPreferences,
                          highRiskSymptoms: riskSymptoms,
                          needsMedicalReview: medicalReview,
                          setup: focus == BilPlanFocus.nutrition
                              ? null
                              : BilPlanSetup(
                                  environment: environment,
                                  experience: experience!,
                                  sessionMinutes: minutes,
                                  equipment:
                                      environment == BilPlanEnvironment.gym
                                      ? {'gym'}
                                      : equipment,
                                  preferredTime: preferredTime,
                                ),
                        ),
                      )
                    : null,
                child: Text(t('Prepare a draft', 'تجهيز المسودة')),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'No HealthKit writes, food logging, or AI submission occurs when preparing a draft.',
                  'إنشاء المسودة لا يكتب في HealthKit أو سجل الطعام ولا يرسل بيانات إلى الذكاء الاصطناعي.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
