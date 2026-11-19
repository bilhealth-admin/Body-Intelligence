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
  final MealPlanDiet? diet;
  final bool confirmedPreferences, highRiskSymptoms, needsMedicalReview;
  final BilPlanSetup? setup;
}

class _PlanCreationSheet extends StatefulWidget {
  const _PlanCreationSheet({
    required this.isCurrent,
    this.initialHorizon,
    this.initialFocus,
    this.initialSetup,
    this.initialSessionsPerWeek,
    this.initialOptions,
  });
  final bool Function() isCurrent;
  final BilPlanHorizon? initialHorizon;
  final BilPlanFocus? initialFocus;
  final BilPlanSetup? initialSetup;
  final int? initialSessionsPerWeek;
  final _PlanOptions? initialOptions;

  @override
  State<_PlanCreationSheet> createState() => _PlanCreationSheetState();
}

class _PlanCreationSheetState extends State<_PlanCreationSheet> {
  BilPlanHorizon? horizon;
  BilPlanFocus? focus;
  MealPlanDiet? diet;
  int? sessions;
  bool confirmedPreferences = false;
  bool? riskSymptoms;
  bool? medicalReview;
  BilPlanEnvironment? environment;
  BilPlanExperience? experience;
  int? minutes;
  String? preferredTime;
  final equipment = <String>{};

  final _anchors = <String, GlobalKey>{
    for (final field in _planRequiredFields)
      field: GlobalKey(debugLabel: field),
  };
  final _focusNodes = <String, FocusNode>{
    for (final field in _planRequiredFields)
      field: FocusNode(debugLabel: field),
  };
  bool _validationOpen = false;
  bool get _current => mounted && widget.isCurrent();

  Widget _anchor(String field, Widget child) => KeyedSubtree(
    key: _anchors[field],
    child: KeyedSubtree(
      key: ValueKey('bil-smart-plan-field-$field'),
      child: child,
    ),
  );

  Widget _medicalChoice(
    String field,
    bool? value,
    ValueChanged<bool?> onChanged,
    String label,
  ) => _anchor(
    field,
    Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Semantics(
            label: label,
            child: DropdownButtonFormField<bool>(
              focusNode: _focusNodes[field],
              isExpanded: true,
              initialValue: value,
              hint: Text(_planValidationCopy(context, 1)),
              items: [
                DropdownMenuItem(
                  value: true,
                  child: Text(_planValidationCopy(context, 2)),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text(_planValidationCopy(context, 3)),
                ),
              ],
              onChanged: onChanged,
              icon: const BilCrystalArrow(
                extent: 36,
                child: Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  List<_MissingPlanChoice> _missingChoices() {
    final labels = _planRequiredLabels(context);
    final training = focus != BilPlanFocus.nutrition;
    final nutrition = focus != BilPlanFocus.training;
    final missing = <String>[
      if (horizon == null) 'horizon',
      if (focus == null) 'focus',
      if (training && environment == null) 'environment',
      if (training && experience == null) 'experience',
      if (training && minutes == null) 'minutes',
      if (training && sessions == null) 'sessions',
      if (training &&
          environment == BilPlanEnvironment.home &&
          equipment.isEmpty)
        'equipment',
      if (nutrition && diet == null) 'diet',
      if (!confirmedPreferences) 'confirmation',
      if (riskSymptoms == null) 'symptoms',
      if (medicalReview == null) 'medical',
    ];
    return [
      for (final field in missing) _MissingPlanChoice(field, labels[field]!),
    ];
  }

  Future<void> _validateAndSubmit() async {
    if (!_current || _validationOpen) return;
    final missing = _missingChoices();
    final needsReview = riskSymptoms == true || medicalReview == true;
    if (missing.isNotEmpty || needsReview) {
      final labels = _planRequiredLabels(context);
      final choices = missing.isNotEmpty
          ? missing
          : [
              if (riskSymptoms == true)
                _MissingPlanChoice('symptoms', labels['symptoms']!),
              if (medicalReview == true)
                _MissingPlanChoice('medical', labels['medical']!),
            ];
      String? field;
      _validationOpen = true;
      try {
        field = await _showPlanChoiceReview(
          context,
          choices,
          medical: missing.isEmpty && needsReview,
          isCurrent: () => _current,
        );
      } finally {
        _validationOpen = false;
      }
      if (!mounted || !_current || field == null) return;
      final target = _anchors[field]?.currentContext;
      if (target == null || !target.mounted) return;
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
        alignment: .15,
      );
      if (_current) _focusNodes[field]?.requestFocus();
      return;
    }
    Navigator.pop(
      context,
      _PlanOptions(
        horizon: horizon!,
        focus: focus!,
        workoutsPerWeek: focus == BilPlanFocus.nutrition ? 0 : sessions!,
        diet: diet,
        confirmedPreferences: confirmedPreferences,
        highRiskSymptoms: riskSymptoms!,
        needsMedicalReview: medicalReview!,
        setup: focus == BilPlanFocus.nutrition
            ? null
            : BilPlanSetup(
                environment: environment!,
                experience: experience!,
                sessionMinutes: minutes!,
                equipment: environment == BilPlanEnvironment.gym
                    ? {'gym'}
                    : equipment,
                preferredTime: preferredTime,
              ),
      ),
    );
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final retry = widget.initialOptions;
    horizon = retry?.horizon ?? widget.initialHorizon;
    focus = retry?.focus ?? widget.initialFocus;
    if (retry != null) {
      diet = retry.diet;
      confirmedPreferences = retry.confirmedPreferences;
      riskSymptoms = retry.highRiskSymptoms;
      medicalReview = retry.needsMedicalReview;
    }
    final saved = retry?.setup ?? widget.initialSetup;
    if (saved != null) {
      environment = saved.environment;
      experience = saved.experience;
      minutes = saved.sessionMinutes;
      preferredTime = saved.preferredTime;
      if (saved.environment == BilPlanEnvironment.home) {
        equipment
          ..clear()
          ..addAll(saved.equipment);
        // Older saved setups carried the bodyweight marker alongside real
        // equipment. The new explicit "No equipment" choice is exclusive.
        if (equipment.length > 1) equipment.remove('none');
      }
    }
    final frequency = retry?.workoutsPerWeek ?? widget.initialSessionsPerWeek;
    if (frequency != null && frequency >= 1 && frequency <= 6) {
      sessions = frequency;
    }
    if (environment == BilPlanEnvironment.home && (sessions ?? 0) > 3) {
      sessions = null;
    }
    // New replacements require fresh confirmation; only this owner/visit retry
    // recovers its still-unsubmitted choices and confirmation.
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String arabic) => _smartPlanText(context, en, arabic);
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
              _anchor(
                'horizon',
                DropdownButtonFormField<BilPlanHorizon>(
                  focusNode: _focusNodes['horizon'],
                  decoration: InputDecoration(
                    labelText: t('Duration', 'المدة'),
                  ),
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

                  icon: const BilCrystalArrow(
                    extent: 36,
                    child: Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _anchor(
                'focus',
                DropdownButtonFormField<BilPlanFocus>(
                  focusNode: _focusNodes['focus'],
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

                  icon: const BilCrystalArrow(
                    extent: 36,
                    child: Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
              ),
              if (focus != BilPlanFocus.nutrition) ...[
                const SizedBox(height: 16),
                _anchor(
                  'environment',
                  DropdownButtonFormField<BilPlanEnvironment>(
                    focusNode: _focusNodes['environment'],
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
                          (sessions ?? 0) > 3) {
                        sessions = null;
                      }
                    }),

                    icon: const BilCrystalArrow(
                      extent: 36,
                      child: Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _anchor(
                  'experience',
                  DropdownButtonFormField<BilPlanExperience>(
                    focusNode: _focusNodes['experience'],
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

                    icon: const BilCrystalArrow(
                      extent: 36,
                      child: Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _anchor(
                  'minutes',
                  DropdownButtonFormField<int>(
                    focusNode: _focusNodes['minutes'],
                    isExpanded: true,
                    initialValue: minutes,
                    decoration: InputDecoration(
                      labelText: t(
                        'Your session time budget: ',
                        'الوقت المتاح للجلسة: ',
                      ).trim(),
                    ),
                    items: [
                      for (final value in (<int>{
                        for (var n = 10; n <= 90; n += 5) n,
                        ?minutes,
                      }.toList()..sort()))
                        DropdownMenuItem(
                          value: value,
                          child: Text('$value${t(' min', ' دقيقة')}'),
                        ),
                    ],
                    onChanged: (value) => setState(() => minutes = value),
                    icon: const BilCrystalArrow(
                      extent: 36,
                      child: Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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

                  icon: const BilCrystalArrow(
                    extent: 36,
                    child: Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
                if (environment == BilPlanEnvironment.home) ...[
                  const SizedBox(height: 16),
                  _anchor(
                    'equipment',
                    Focus(
                      focusNode: _focusNodes['equipment'],
                      child: Text(t('Available equipment', 'المعدات المتاحة')),
                    ),
                  ),
                  for (final item in [
                    ('none', t('No equipment', 'بدون معدات')),
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
                          if (item.$1 == 'none') {
                            equipment.clear();
                          } else {
                            equipment.remove('none');
                          }
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
                _anchor(
                  'sessions',
                  DropdownButtonFormField<int>(
                    key: ValueKey(('sessions', environment)),
                    focusNode: _focusNodes['sessions'],
                    isExpanded: true,
                    initialValue: sessions,
                    decoration: InputDecoration(
                      labelText: t(
                        'Sessions per week: ',
                        'جلسات التدريب أسبوعيًا: ',
                      ).trim(),
                    ),
                    items: [
                      for (
                        var value = 1;
                        value <=
                            (environment == BilPlanEnvironment.home ? 3 : 6);
                        value++
                      )
                        DropdownMenuItem(value: value, child: Text('$value')),
                    ],
                    onChanged: (value) => setState(() => sessions = value),
                    icon: const BilCrystalArrow(
                      extent: 36,
                      child: Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
                ),
                if (environment != null)
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
                _anchor(
                  'diet',
                  DropdownButtonFormField<MealPlanDiet>(
                    focusNode: _focusNodes['diet'],
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

                    icon: const BilCrystalArrow(
                      extent: 36,
                      child: Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
                ),
              _anchor(
                'confirmation',
                CheckboxListTile(
                  focusNode: _focusNodes['confirmation'],
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
              ),
              _medicalChoice(
                'symptoms',
                riskSymptoms,
                (value) => setState(() => riskSymptoms = value),
                t(
                  'I have concerning symptoms or an injury affecting exercise.',
                  'لدي أعراض مقلقة أو إصابة تؤثر على التمرين.',
                ),
              ),
              _medicalChoice(
                'medical',
                medicalReview,
                (value) => setState(() => medicalReview = value),
                t(
                  'I am pregnant, postpartum, or my diet or training requires clinician supervision.',
                  'أنا حامل أو بعد الولادة، أو يحتاج غذائي أو تدريبي متابعة طبية.',
                ),
              ),
              if (riskSymptoms == true || medicalReview == true)
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
                onPressed: _validateAndSubmit,
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
