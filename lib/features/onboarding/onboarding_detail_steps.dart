part of 'onboarding_page.dart';

extension _OnboardingDetailSteps on _OnboardingPageState {
  _StepView _heightStep() => _numberStep(
    title: t('What is your height?'),
    subtitle: t('Height helps calculate an initial energy estimate.'),
    controller: _height,
    unit: UnitConverter.heightUnit(_draft.system),
    rangeText:
        '${_displayLength(120)}–${_displayLength(250)} '
        '${UnitConverter.heightUnit(_draft.system)}',
    keyName: 'onboarding-height',
    onChanged: (value) => _setDraft(
      _draft.copyWith(
        heightCm: value == null
            ? null
            : UnitConverter.heightToCm(value, _draft.system),
      ),
    ),
  );

  _StepView _currentWeightStep() => _numberStep(
    title: t('What is your current weight?'),
    subtitle: t(
      'This becomes your first local progress entry only after Finish.',
    ),
    controller: _currentWeight,
    unit: UnitConverter.weightUnit(_draft.system),
    rangeText:
        '${_displayWeight(20)}–${_displayWeight(500)} '
        '${UnitConverter.weightUnit(_draft.system)}',
    keyName: 'onboarding-current-weight',
    onChanged: (value) {
      final kg = value == null
          ? null
          : UnitConverter.weightToKg(value, _draft.system);
      final maintain =
          !_draft.goals.contains(OnboardingGoal.loseWeight) &&
          !_draft.goals.contains(OnboardingGoal.gainWeight);
      _setDraft(
        _draft.copyWith(
          currentWeightKg: kg,
          targetWeightKg: maintain ? kg : _draft.targetWeightKg,
          weeklyPaceKg: maintain ? 0 : _draft.weeklyPaceKg,
        ),
      );
      if (maintain) _targetWeight.text = _displayWeight(kg);
    },
  );

  _StepView _targetWeightStep() {
    final maintain = _draft.primaryWeightGoal == 'maintain';
    return _numberStep(
      title: maintain
          ? t('Keep your current weight')
          : t('Choose your target weight'),
      subtitle: maintain
          ? t(
              'BIL will keep the energy estimate neutral and focus on your other goals.',
            )
          : t('Choose a realistic target. You can revise it at any time.'),
      controller: _targetWeight,
      unit: UnitConverter.weightUnit(_draft.system),
      rangeText:
          '${_displayWeight(20)}–${_displayWeight(500)} '
          '${UnitConverter.weightUnit(_draft.system)}',
      keyName: 'onboarding-target-weight',
      enabled: !maintain,
      onChanged: (value) => _setDraft(
        _draft.copyWith(
          targetWeightKg: value == null
              ? null
              : UnitConverter.weightToKg(value, _draft.system),
          weeklyPaceKg: null,
        ),
      ),
    );
  }

  _StepView _numberStep({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String unit,
    required String rangeText,
    required String keyName,
    required ValueChanged<double?> onChanged,
    bool enabled = true,
  }) => _StepView(
    title: title,
    subtitle: subtitle,
    body: TextField(
      key: Key(keyName),
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        suffixText: unit,
        helper: _UnitRangeHint(rangeText),
        border: const OutlineInputBorder(),
      ),
      onChanged: (raw) => onChanged(double.tryParse(raw.replaceAll(',', '.'))),
      onSubmitted: (_) => unawaited(_goNext()),
    ),
  );

  _StepView _paceStep() {
    final options = _draft.currentWeightKg == null
        ? const <double>[]
        : OnboardingPlanCalculator.paceOptions(_draft);
    return _StepView(
      title: t('Choose a weekly pace'),
      subtitle: _draft.primaryWeightGoal == 'maintain'
          ? t('No weekly weight change is applied to your energy estimate.')
          : t('BIL limits this choice to a conservative, non-medical range.'),
      body: Column(
        children: [
          for (final pace in options) ...[
            OnboardingChoiceCard(
              title: pace == 0
                  ? t('Maintain')
                  : '${_displayWeight(pace)} '
                        '${UnitConverter.weightUnit(_draft.system)} / 7d',
              subtitle: pace == options.first && pace != 0
                  ? t('Gentler pace')
                  : null,
              selected: (_draft.weeklyPaceKg ?? -1) == pace,
              onTap: () => _setDraft(_draft.copyWith(weeklyPaceKg: pace)),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          _InfoBanner(
            icon: Icons.health_and_safety_outlined,
            text: t(
              'This is an educational estimate, not medical advice. Stop and seek qualified help if a goal feels unsafe.',
            ),
          ),
        ],
      ),
    );
  }

  _StepView _measurementStep(String field) {
    final title = switch (field) {
      'waist' => t('Add your waist measurement?'),
      'neck' => t('Add your neck measurement?'),
      _ => t('Add your hip measurement?'),
    };
    final controller = switch (field) {
      'waist' => _waist,
      'neck' => _neck,
      _ => _hips,
    };
    return _StepView(
      title: title,
      subtitle: t(
        'Optional. This can improve Body Twin composition estimates and stays local unless you explicitly enable a cloud feature.',
      ),
      skip: () => unawaited(_skipMeasurement(field)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: Key('onboarding-$field'),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              suffixText: UnitConverter.heightUnit(_draft.system),
              helper: _UnitRangeHint(
                '${_displayLength(20)}–${_displayLength(300)} '
                '${UnitConverter.heightUnit(_draft.system)}',
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (raw) {
              final parsed = double.tryParse(raw.replaceAll(',', '.'));
              final cm = parsed == null
                  ? null
                  : UnitConverter.heightToCm(parsed, _draft.system);
              _setDraft(switch (field) {
                'waist' => _draft.copyWith(waistCm: cm),
                'neck' => _draft.copyWith(neckCm: cm),
                _ => _draft.copyWith(hipsCm: cm),
              });
            },
          ),
          const SizedBox(height: 14),
          _InfoBanner(
            icon: Icons.lock_outline_rounded,
            text: t('You can skip this without losing access to BIL.'),
          ),
        ],
      ),
    );
  }

  _StepView _planStep() {
    OnboardingPlanResult? plan;
    String? failure;
    try {
      plan = OnboardingPlanCalculator.calculate(_draft);
    } on Object {
      failure = t(
        'BIL cannot calculate a safe estimate from these values yet.',
      );
    }
    return _StepView(
      title: t('Your starting plan'),
      subtitle: t(
        'Calculated from the facts and pace you chose. Results are not guaranteed.',
      ),
      nextEnabled: plan != null,
      body: plan == null
          ? _ErrorBanner(message: failure!)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlanMetric(
                  label: t('Daily energy estimate'),
                  value: '${plan.targets.calories} kcal',
                  prominent: true,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    final stack = constraints.maxWidth < 310 || scale >= 1.45;
                    final metrics = <Widget>[
                      _PlanMetric(
                        label: t('Protein'),
                        value: '${plan!.targets.protein} g',
                      ),
                      _PlanMetric(
                        label: t('Carbs'),
                        value: '${plan.targets.carbs} g',
                      ),
                      _PlanMetric(
                        label: t('Fat'),
                        value: '${plan.targets.fats} g',
                      ),
                    ];
                    if (stack) {
                      return Column(
                        children: [
                          for (
                            var index = 0;
                            index < metrics.length;
                            index++
                          ) ...[
                            SizedBox(
                              width: double.infinity,
                              child: metrics[index],
                            ),
                            if (index != metrics.length - 1)
                              const SizedBox(height: 8),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (
                          var index = 0;
                          index < metrics.length;
                          index++
                        ) ...[
                          Expanded(child: metrics[index]),
                          if (index != metrics.length - 1)
                            const SizedBox(width: 8),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _InfoBanner(
                  icon: Icons.science_outlined,
                  text: t(
                    'Source: Mifflin–St Jeor baseline, your activity selection, and 7,700 kcal per kg for the chosen weekly pace. Logged exercise remains separate.',
                  ),
                ),
                if (plan.targetDate case final date?) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${t('Estimated target window')}: ${MaterialLocalizations.of(context).formatMediumDate(date)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ],
            ),
    );
  }

  _StepView _integrationsStep() {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final supported = isIos || isAndroid;
    final healthName = isIos
        ? 'Apple Health'
        : isAndroid
        ? 'Health Connect'
        : t('Connected health');
    return _StepView(
      title: t('Optional connections'),
      subtitle: t(
        'BIL explains each benefit before requesting a system permission.',
      ),
      skip: () => unawaited(_goNext()),
      body: Column(
        children: [
          OnboardingStatusCard(
            icon: Icons.favorite_outline_rounded,
            title: healthName,
            body: supported
                ? t(
                    'Import supported activity, steps, sleep and weight evidence you approve. Only compatible fitness watches and scales can feed this system source.',
                  )
                : t('This connection is unavailable on this device.'),
            status: _permissionStatus(_draft.healthPermission),
            action: !supported || _permissionBusy
                ? null
                : () => unawaited(_requestHealth()),
            actionLabel: t('Review permission'),
          ),
          const SizedBox(height: 12),
          OnboardingStatusCard(
            icon: Icons.notifications_none_rounded,
            title: t('Notifications'),
            body: t(
              'Allow optional reminders for habits you configure. BIL does not schedule them until you choose a reminder.',
            ),
            status: _permissionStatus(_draft.notificationPermission),
            action: _permissionBusy
                ? null
                : () => unawaited(_requestNotifications()),
            actionLabel: t('Review permission'),
          ),
        ],
      ),
    );
  }

  String _permissionStatus(OnboardingPermissionStatus value) => switch (value) {
    OnboardingPermissionStatus.notRequested => t('Not requested'),
    OnboardingPermissionStatus.requested => t('Requested'),
    OnboardingPermissionStatus.granted => t('Allowed'),
    OnboardingPermissionStatus.denied => t('Not allowed'),
    OnboardingPermissionStatus.unavailable => t('Unavailable'),
    OnboardingPermissionStatus.failed => t('Try again'),
  };

  Future<void> _requestHealth() async {
    if (_permissionBusy) return;
    _updateState(() => _permissionBusy = true);
    await ref.read(connectedHealthProvider.notifier).requestPermissions();
    final state = ref.read(connectedHealthProvider);
    final status = state.when(
      data: _healthPermissionStatus,
      error: (_, _) => OnboardingPermissionStatus.failed,
      loading: () => OnboardingPermissionStatus.requested,
    );
    if (!mounted) return;
    _updateState(() => _permissionBusy = false);
    _setDraft(_draft.copyWith(healthPermission: status), persist: true);
  }

  OnboardingPermissionStatus _healthPermissionStatus(
    ConnectedHealthSnapshot value,
  ) => switch (value.status) {
    ConnectedHealthStatus.ready ||
    ConnectedHealthStatus.synchronized ||
    ConnectedHealthStatus.syncing => OnboardingPermissionStatus.granted,
    ConnectedHealthStatus.authorizationRequested =>
      OnboardingPermissionStatus.requested,
    ConnectedHealthStatus.permissionDenied => OnboardingPermissionStatus.denied,
    ConnectedHealthStatus.unavailable => OnboardingPermissionStatus.unavailable,
    ConnectedHealthStatus.updateRequired ||
    ConnectedHealthStatus.degraded => OnboardingPermissionStatus.failed,
    ConnectedHealthStatus.permissionRequired =>
      OnboardingPermissionStatus.notRequested,
  };

  Future<void> _requestNotifications() async {
    if (_permissionBusy) return;
    _updateState(() => _permissionBusy = true);
    OnboardingPermissionStatus status;
    try {
      final allowed = await ref
          .read(onboardingNotificationGatewayProvider)
          .requestPermission();
      status = allowed
          ? OnboardingPermissionStatus.granted
          : OnboardingPermissionStatus.denied;
    } on Object {
      status = OnboardingPermissionStatus.failed;
    }
    if (!mounted) return;
    _updateState(() => _permissionBusy = false);
    _setDraft(_draft.copyWith(notificationPermission: status), persist: true);
  }

  _StepView _aiStep() {
    final options = <(CoachContextFocus, String, IconData)>[
      (
        CoachContextFocus.nutrition,
        t('Nutrition and meals'),
        Icons.restaurant_menu_rounded,
      ),
      (
        CoachContextFocus.training,
        t('Training and activity'),
        Icons.directions_run_rounded,
      ),
      (
        CoachContextFocus.habits,
        t('Sleep, fasting and habits'),
        Icons.bedtime_outlined,
      ),
      (
        CoachContextFocus.analytics,
        t('Progress analytics'),
        Icons.insights_rounded,
      ),
    ];
    return _StepView(
      title: t('Choose whether to use cloud AI'),
      subtitle: t(
        'AI Coach is optional, is not a doctor, and receives text context only after explicit consent. Voice recognition remains separate from this consent.',
      ),
      skip: () => unawaited(_setAiConsent(false, thenContinue: true)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options) ...[
            OnboardingChoiceCard(
              title: option.$2,
              icon: option.$3,
              selected: _draft.aiFocuses.contains(option.$1),
              onTap: () {
                final next = {..._draft.aiFocuses};
                next.contains(option.$1)
                    ? next.remove(option.$1)
                    : next.add(option.$1);
                _setDraft(_draft.copyWith(aiFocuses: next));
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('onboarding-enable-ai'),
            onPressed: _permissionBusy || _draft.aiFocuses.isEmpty
                ? null
                : () => unawaited(_setAiConsent(true)),
            icon: const Icon(Icons.cloud_done_outlined),
            label: Text(t('I agree — enable cloud AI')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('onboarding-decline-ai'),
            onPressed: _permissionBusy
                ? null
                : () => unawaited(_setAiConsent(false)),
            child: Text(t('Keep cloud AI off')),
          ),
          if (_aiStatusMessage case final message?) ...[
            const SizedBox(height: 12),
            _InfoBanner(icon: Icons.info_outline_rounded, text: message),
          ],
        ],
      ),
    );
  }

  Future<void> _setAiConsent(bool granted, {bool thenContinue = false}) async {
    if (_permissionBusy) return;
    _updateState(() {
      _permissionBusy = true;
      _aiStatusMessage = null;
    });
    final result = await ref
        .read(onboardingRemoteAiGatewayProvider)
        .setGranted(granted);
    if (!mounted) return;
    final consent = switch (result) {
      OnboardingRemoteAiResult.granted => OnboardingRemoteAiConsent.granted,
      OnboardingRemoteAiResult.declined => OnboardingRemoteAiConsent.declined,
      OnboardingRemoteAiResult.authenticationRequired when !granted =>
        OnboardingRemoteAiConsent.declined,
      _ => OnboardingRemoteAiConsent.unknown,
    };
    final message = switch (result) {
      OnboardingRemoteAiResult.authenticationRequired =>
        granted
            ? t('Sign in later to grant cloud AI consent. AI remains off now.')
            : t('Cloud AI remains off in local mode.'),
      OnboardingRemoteAiResult.failed => t(
        'Consent could not be verified. AI remains off and nothing was sent.',
      ),
      OnboardingRemoteAiResult.granted => t('Cloud AI consent is active.'),
      OnboardingRemoteAiResult.declined => t('Cloud AI is off.'),
    };
    _updateState(() {
      _permissionBusy = false;
      _aiStatusMessage = message;
      _draft = _draft.copyWith(remoteAiConsent: consent);
    });
    await _queueDraftSave();
    if (thenContinue && consent == OnboardingRemoteAiConsent.declined) {
      await _goNext();
    }
  }

  _StepView _reviewStep() {
    final localAi = _draft.remoteAiConsent == OnboardingRemoteAiConsent.granted
        ? t('Cloud AI enabled by explicit consent')
        : t('Cloud AI off');
    return _StepView(
      title: t('Ready to start'),
      subtitle: t(
        'Nothing changes in your profile until you finish this step.',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoBanner(
            icon: Icons.verified_user_outlined,
            text: '${t('Local-first setup')} · $localAi',
          ),
          const SizedBox(height: 14),
          CheckboxListTile(
            key: const Key('onboarding-estimates-ack'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _draft.estimatesAcknowledged,
            title: Text(
              t(
                'I understand these are educational estimates, not medical advice or guaranteed results.',
              ),
            ),
            onChanged: (value) => _setDraft(
              _draft.copyWith(estimatesAcknowledged: value == true),
              persist: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => context.push('/legal/privacy'),
                child: Text(t('Privacy Policy')),
              ),
              TextButton(
                onPressed: () => context.push('/legal/terms'),
                child: Text(t('Terms of Use')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
