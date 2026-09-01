part of 'onboarding_page.dart';

extension _OnboardingCoreSteps on _OnboardingPageState {
  _StepView _stepView(String id) => switch (id) {
    'name' => _nameStep(),
    'goals' => _goalsStep(),
    'activity' => _activityStep(),
    'facts' => _factsStep(),
    'units' => _unitsStep(),
    'height' => _heightStep(),
    'currentWeight' => _currentWeightStep(),
    'targetWeight' => _targetWeightStep(),
    'pace' => _paceStep(),
    'waist' => _measurementStep('waist'),
    'neck' => _measurementStep('neck'),
    'hips' => _measurementStep('hips'),
    'plan' => _planStep(),
    'integrations' => _integrationsStep(),
    'ai' => _aiStep(),
    _ => _reviewStep(),
  };

  _StepView _nameStep() => _StepView(
    title: t('What should BIL call you?'),
    subtitle: t(
      'This name stays on this device unless you later choose account sync.',
    ),
    body: TextField(
      key: const Key('onboarding-name-field'),
      controller: _name,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.nickname],
      decoration: InputDecoration(
        labelText: t('Preferred name'),
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) => _setDraft(_draft.copyWith(preferredName: value)),
      onSubmitted: (_) => unawaited(_goNext()),
    ),
  );

  _StepView _goalsStep() {
    final options = <(OnboardingGoal, String, String, IconData)>[
      (
        OnboardingGoal.loseWeight,
        t('Lose weight'),
        t('A gradual energy target and progress forecast.'),
        Icons.south_east_rounded,
      ),
      (
        OnboardingGoal.maintainWeight,
        t('Maintain weight'),
        t('Keep weight steady while improving daily habits.'),
        Icons.balance_rounded,
      ),
      (
        OnboardingGoal.gainWeight,
        t('Gain weight'),
        t('A controlled surplus based on your chosen pace.'),
        Icons.north_east_rounded,
      ),
      (
        OnboardingGoal.buildMuscle,
        t('Build muscle'),
        t('Higher protein guidance and training-aware coaching.'),
        Icons.fitness_center_rounded,
      ),
      (
        OnboardingGoal.improveNutrition,
        t('Improve nutrition'),
        t('Use food quality, calories and macros together.'),
        Icons.restaurant_rounded,
      ),
      (
        OnboardingGoal.planMeals,
        t('Plan meals'),
        t('Make recipes and meal planning part of your routine.'),
        Icons.calendar_month_rounded,
      ),
      (
        OnboardingGoal.activityFitness,
        t('Activity and fitness'),
        t('Use workouts and verified activity as separate evidence.'),
        Icons.directions_run_rounded,
      ),
      (
        OnboardingGoal.sleepRecovery,
        t('Sleep and recovery'),
        t('Include sleep patterns in habit coaching.'),
        Icons.bedtime_rounded,
      ),
      (
        OnboardingGoal.fastingHabits,
        t('Fasting and habits'),
        t('Support routines without medical claims.'),
        Icons.timelapse_rounded,
      ),
      (
        OnboardingGoal.stressWellbeing,
        t('Stress and wellbeing'),
        t('Use the wellbeing check-ins you choose to record.'),
        Icons.self_improvement_rounded,
      ),
    ];
    return _StepView(
      title: t('What would you like to work on?'),
      subtitle: t(
        'Choose more than one. You can change these priorities later.',
      ),
      body: Column(
        children: [
          for (final option in options) ...[
            OnboardingChoiceCard(
              title: option.$2,
              subtitle: option.$3,
              icon: option.$4,
              selected: _draft.goals.contains(option.$1),
              onTap: () => _toggleGoal(option.$1),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  void _toggleGoal(OnboardingGoal goal) {
    final goals = {..._draft.goals};
    if (goals.contains(goal)) {
      goals.remove(goal);
    } else {
      if (_OnboardingPageState._weightGoals.contains(goal)) {
        goals.removeAll(_OnboardingPageState._weightGoals);
      }
      goals.add(goal);
    }
    var target = _draft.targetWeightKg;
    var pace = _draft.weeklyPaceKg;
    final hasDirection =
        goals.contains(OnboardingGoal.loseWeight) ||
        goals.contains(OnboardingGoal.gainWeight);
    if (!hasDirection && _draft.currentWeightKg != null) {
      target = _draft.currentWeightKg;
      pace = 0;
    } else if (hasDirection) {
      if (target == _draft.currentWeightKg) target = null;
      pace = null;
    }
    _setDraft(
      _draft.copyWith(
        goals: goals,
        targetWeightKg: target,
        weeklyPaceKg: pace,
        aiFocuses: OnboardingGoalBindings.suggestedAiFocuses(goals),
      ),
    );
    _targetWeight.text = _displayWeight(target);
  }

  _StepView _activityStep() {
    final values = <(String, String, String)>[
      (
        'sedentary',
        t('Mostly seated'),
        t('Little movement outside daily tasks.'),
      ),
      ('light', t('Lightly active'), t('Some walking or standing most days.')),
      (
        'moderate',
        t('Moderately active'),
        t('Regular movement through work or daily life.'),
      ),
      (
        'active',
        t('Very active'),
        t('Physically active through much of the day.'),
      ),
      (
        'veryActive',
        t('Exceptionally active'),
        t('Demanding physical work most days.'),
      ),
    ];
    return _StepView(
      title: t('What is your baseline activity?'),
      subtitle: t(
        'Do not count workouts here. BIL records exercise separately.',
      ),
      body: Column(
        children: [
          for (final value in values) ...[
            OnboardingChoiceCard(
              title: value.$2,
              subtitle: value.$3,
              selected: _draft.activity == value.$1,
              onTap: () => _setDraft(_draft.copyWith(activity: value.$1)),
            ),
            const SizedBox(height: 10),
          ],
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(t('I also exercise regularly')),
            subtitle: Text(
              t('Exercise remains separate from baseline activity.'),
            ),
            value: _draft.regularExercise,
            onChanged: (value) =>
                _setDraft(_draft.copyWith(regularExercise: value)),
          ),
        ],
      ),
    );
  }

  _StepView _factsStep() => _StepView(
    title: t('A few facts for your estimate'),
    subtitle: t(
      'These are used by the calorie equation. BIL is for adults 18+.',
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('Sex used by the equation'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final stack = constraints.maxWidth < 300 || scale >= 1.6;
            final female = OnboardingChoiceCard(
              title: t('Female'),
              selected: _draft.sex == 'female',
              onTap: () => _setSex('female'),
            );
            final male = OnboardingChoiceCard(
              title: t('Male'),
              selected: _draft.sex == 'male',
              onTap: () => _setSex('male'),
            );
            if (stack) {
              return Column(
                children: [female, const SizedBox(height: 10), male],
              );
            }
            return Row(
              children: [
                Expanded(child: female),
                const SizedBox(width: 10),
                Expanded(child: male),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          key: const Key('onboarding-birth-date'),
          onPressed: _pickBirthDate,
          icon: const Icon(Icons.cake_outlined),
          label: Text(
            _draft.birthDate == null
                ? t('Choose date of birth')
                : MaterialLocalizations.of(
                    context,
                  ).formatCompactDate(_draft.birthDate!),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const Key('onboarding-country'),
          controller: _country,
          readOnly: true,
          onTap: _pickCountry,
          decoration: InputDecoration(
            labelText: t('Country or region'),
            helperText: '${t('App language')}: ${_draft.localeTag}',
            suffixIcon: IconButton(
              tooltip: t('Country or region'),
              onPressed: _pickCountry,
              icon: const Icon(Icons.arrow_drop_down_rounded),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
  );

  void _pickCountry() {
    showCountryPicker(
      context: context,
      useSafeArea: true,
      showPhoneCode: false,
      searchAutofocus: true,
      countryListTheme: CountryListThemeData(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        inputDecoration: InputDecoration(
          labelText: t('Country or region'),
          prefixIcon: const Icon(Icons.search_rounded),
          border: const OutlineInputBorder(),
        ),
      ),
      onSelect: (country) {
        final localizedName = country.nameLocalized?.trim();
        final countryName = localizedName == null || localizedName.isEmpty
            ? country.name.trim()
            : localizedName;
        _country.text = countryName;
        _setDraft(_draft.copyWith(countryRegion: countryName), persist: true);
      },
    );
  }

  void _setSex(String value) {
    final oldId = _stepId;
    if (value != 'female') _hips.clear();
    _setDraft(
      _draft.copyWith(
        sex: value,
        hipsCm: value == 'female' ? _draft.hipsCm : null,
      ),
      persist: true,
    );
    final newIndex = _steps.indexOf(oldId);
    if (newIndex >= 0) _index = newIndex;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final latest = BilAdultEligibility.latestEligibleBirthDate(on: now);
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _draft.birthDate ??
          DateTime(latest.year - 12, latest.month, latest.day),
      firstDate: DateTime(now.year - 120),
      lastDate: latest,
      helpText: t('Date of birth'),
    );
    if (selected != null) _setDraft(_draft.copyWith(birthDate: selected));
  }

  _StepView _unitsStep() => _StepView(
    title: t('Choose your units'),
    subtitle: t(
      'You can switch units without changing the stored measurements.',
    ),
    body: _UnitToggleCard(
      imperial: _draft.system == MeasurementSystem.imperial,
      metricLabel: t('Metric'),
      metricSubtitle: t('Centimetres and kilograms'),
      imperialLabel: t('Imperial'),
      imperialSubtitle: t('Inches and pounds'),
      semanticLabel: t('Choose your units'),
      onTap: () => _changeUnits(
        _draft.system == MeasurementSystem.metric
            ? MeasurementSystem.imperial
            : MeasurementSystem.metric,
      ),
    ),
  );

  void _changeUnits(MeasurementSystem value) {
    if (_draft.system == value) return;
    // Measurements remain canonical cm/kg. Only their live field rendering is
    // switched, so repeated metric/imperial round trips cannot accumulate
    // conversion drift.
    _setDraft(_draft.copyWith(system: value), persist: true);
    _syncControllers();
  }
}
