import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/bil_locale_policy.dart';
import '../../core/units/measurement_units.dart';
import '../../data/database/database_provider.dart';
import '../../shared/widgets/bil_coach_identity.dart';
import '../connected_health/connected_health_model.dart';
import '../connected_health/providers/connected_health_provider.dart';
import '../intelligence_center/domain/coach_context_preferences.dart';
import '../intelligence_center/services/coach_context_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'domain/adult_eligibility.dart';
import 'domain/onboarding_completion_service.dart';
import 'domain/onboarding_goal_bindings.dart';
import 'domain/onboarding_plan_calculator.dart';
import 'models/onboarding_draft.dart';
import 'onboarding_runtime_copy.dart';
import 'services/onboarding_permission_gateways.dart';
import 'widgets/modern_onboarding_scaffold.dart';

part 'onboarding_core_steps.dart';
part 'onboarding_detail_steps.dart';
part 'onboarding_components.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _weightGoals = <OnboardingGoal>{
    OnboardingGoal.loseWeight,
    OnboardingGoal.maintainWeight,
    OnboardingGoal.gainWeight,
  };

  final _name = TextEditingController();
  final _country = TextEditingController();
  final _height = TextEditingController();
  final _currentWeight = TextEditingController();
  final _targetWeight = TextEditingController();
  final _waist = TextEditingController();
  final _neck = TextEditingController();
  final _hips = TextEditingController();

  OnboardingDraft _draft = const OnboardingDraft();
  int _index = 0;
  bool _loaded = false;
  bool _loadFailed = false;
  bool _busy = false;
  bool _transitionBusy = false;
  bool _permissionBusy = false;
  String? _inlineError;
  String? _aiStatusMessage;
  Future<void> _draftWrites = Future<void>.value();

  List<String> get _steps => <String>[
    'name',
    'goals',
    'activity',
    'facts',
    'units',
    'height',
    'currentWeight',
    'targetWeight',
    'pace',
    'waist',
    'neck',
    if (_draft.sex == 'female') 'hips',
    'plan',
    'integrations',
    'ai',
    'review',
  ];

  String get _stepId => _steps[_index.clamp(0, _steps.length - 1)];
  String t(String value) =>
      OnboardingRuntimeCopy.resolve(value, Localizations.localeOf(context));

  void _updateState(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _country,
      _height,
      _currentWeight,
      _targetWeight,
      _waist,
      _neck,
      _hips,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final draftRepository = ref.read(onboardingDraftRepositoryProvider);
      var value = await draftRepository.load();
      if (value == null) {
        final preferences = ref.read(preferencesRepositoryProvider);
        final profile = await ref
            .read(userProfileRepositoryProvider)
            .getProfile();
        final latestWeights = await ref.read(weightRepositoryProvider).getAll();
        final measurement = await ref
            .read(bodyMeasurementRepositoryProvider)
            .getLatest();
        final activeGoal = await ref.read(goalRepositoryProvider).getActive();
        final units = await preferences.get('units');
        final storedGoals = OnboardingGoalBindings.decode(
          await preferences.get(OnboardingGoalBindings.storageKey),
        );
        final storedCoachContext = await preferences.get(
          CoachContextPreferences.storageKey,
        );
        final inferredGoal = switch (activeGoal?.type) {
          'lose' => OnboardingGoal.loseWeight,
          'gain' => OnboardingGoal.gainWeight,
          _ => OnboardingGoal.maintainWeight,
        };
        final goalSet = storedGoals.isNotEmpty
            ? storedGoals
            : profile == null
            ? const <OnboardingGoal>{}
            : <OnboardingGoal>{inferredGoal};
        final birthDate = DateTime.tryParse(
          await preferences.get('profileDateOfBirth') ?? '',
        );
        final currentWeight = latestWeights.isNotEmpty
            ? latestWeights.first.weight
            : profile?.currentWeight;
        value = OnboardingDraft(
          preferredName: await preferences.get('displayName') ?? '',
          goals: goalSet,
          activity: profile?.activityLevel,
          regularExercise: profile?.exercises ?? false,
          birthDate: birthDate,
          sex: profile?.gender,
          countryRegion: await preferences.get('countryRegion') ?? '',
          localeTag:
              BilLocalePolicy.canonicalSupportedTag(
                await preferences.get('locale'),
              ) ??
              BilLocalePolicy.canonicalTag(
                WidgetsBinding.instance.platformDispatcher.locale,
              ),
          system: units == 'imperial'
              ? MeasurementSystem.imperial
              : MeasurementSystem.metric,
          heightCm: profile?.height,
          currentWeightKg: currentWeight,
          targetWeightKg: profile?.targetWeight,
          weeklyPaceKg: _restoredPace(
            currentWeight,
            profile?.targetWeight,
            activeGoal?.targetDate,
          ),
          waistCm: measurement?.waistCm ?? profile?.waist,
          neckCm: measurement?.neckCm ?? profile?.neck,
          hipsCm: profile?.gender == 'female' ? measurement?.hipsCm : null,
          aiFocuses: storedCoachContext == null
              ? OnboardingGoalBindings.suggestedAiFocuses(goalSet)
              : CoachContextPreferences.decode(storedCoachContext).focuses,
        );
      }

      final remoteResult = await ref
          .read(onboardingRemoteAiGatewayProvider)
          .read();
      value = value.copyWith(
        remoteAiConsent: switch (remoteResult) {
          OnboardingRemoteAiResult.granted => OnboardingRemoteAiConsent.granted,
          OnboardingRemoteAiResult.declined =>
            OnboardingRemoteAiConsent.declined,
          _ when value.remoteAiConsent == OnboardingRemoteAiConsent.declined =>
            OnboardingRemoteAiConsent.declined,
          _ => OnboardingRemoteAiConsent.unknown,
        },
      );

      if (!mounted) return;
      setState(() {
        _draft = value!;
        final restored = _steps.indexOf(value.stepId);
        _index = restored < 0 ? 0 : restored;
        _loaded = true;
        _loadFailed = false;
      });
      _syncControllers();
    } on Object {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _loadFailed = true;
      });
    }
  }

  static double? _restoredPace(
    double? current,
    double? target,
    DateTime? targetDate,
  ) {
    if (current == null || target == null || (target - current).abs() < .1) {
      return 0;
    }
    if (targetDate == null || !targetDate.isAfter(DateTime.now())) return null;
    final weeks = targetDate.difference(DateTime.now()).inDays / 7;
    if (weeks <= 0) return null;
    return ((target - current).abs() / weeks).clamp(.1, 1).toDouble();
  }

  void _syncControllers() {
    _name.text = _draft.preferredName;
    _country.text = _draft.countryRegion;
    _height.text = _displayLength(_draft.heightCm);
    _currentWeight.text = _displayWeight(_draft.currentWeightKg);
    _targetWeight.text = _displayWeight(_draft.targetWeightKg);
    _waist.text = _displayLength(_draft.waistCm);
    _neck.text = _displayLength(_draft.neckCm);
    _hips.text = _displayLength(_draft.hipsCm);
  }

  String _displayLength(double? cm) {
    if (cm == null) return '';
    final value = UnitConverter.heightFromCm(cm, _draft.system);
    return value
        .toStringAsFixed(_draft.system == MeasurementSystem.metric ? 1 : 2)
        .replaceFirst(RegExp(r'\.0+$'), '');
  }

  String _displayWeight(double? kg) {
    if (kg == null) return '';
    final value = UnitConverter.weightFromKg(kg, _draft.system);
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _setDraft(OnboardingDraft value, {bool persist = false}) {
    setState(() {
      _draft = value;
      _inlineError = null;
    });
    if (persist) _queueDraftSave(value);
  }

  Future<void> _queueDraftSave([OnboardingDraft? snapshot]) {
    final value = snapshot ?? _draft;
    _draftWrites = _draftWrites
        .catchError((Object _) {})
        .then((_) => ref.read(onboardingDraftRepositoryProvider).save(value));
    return _draftWrites;
  }

  Future<void> _goNext() async {
    if (_busy || _transitionBusy || _permissionBusy) return;
    final message = _validateStep(_stepId);
    if (message != null) {
      setState(() => _inlineError = message);
      return;
    }
    setState(() => _transitionBusy = true);
    try {
      if (_index >= _steps.length - 1) {
        await _complete();
        return;
      }
      final next = _steps[_index + 1];
      final nextDraft = _draft.copyWith(stepId: next);
      await _queueDraftSave(nextDraft);
      if (!mounted) return;
      setState(() {
        _draft = nextDraft;
        _index += 1;
        _inlineError = null;
      });
    } on Object {
      if (!mounted) return;
      setState(
        () => _inlineError = t(
          'Nothing was changed because BIL could not save the complete setup. Try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _transitionBusy = false);
    }
  }

  Future<void> _goBack() async {
    if (_busy || _transitionBusy || _permissionBusy) return;
    setState(() => _transitionBusy = true);
    try {
      if (_index == 0) {
        final savedDraft = _draft.copyWith(stepId: 'name');
        await _queueDraftSave(savedDraft);
        if (mounted) context.go('/account-gateway');
        return;
      }
      final previous = _steps[_index - 1];
      final nextDraft = _draft.copyWith(stepId: previous);
      await _queueDraftSave(nextDraft);
      if (!mounted) return;
      setState(() {
        _draft = nextDraft;
        _index -= 1;
        _inlineError = null;
      });
    } on Object {
      if (!mounted) return;
      setState(
        () => _inlineError = t(
          'Nothing was changed because BIL could not save the complete setup. Try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _transitionBusy = false);
    }
  }

  Future<void> _skipMeasurement(String field) async {
    final updated = switch (field) {
      'waist' => _draft.copyWith(waistCm: null),
      'neck' => _draft.copyWith(neckCm: null),
      'hips' => _draft.copyWith(hipsCm: null),
      _ => _draft,
    };
    if (field == 'waist') _waist.clear();
    if (field == 'neck') _neck.clear();
    if (field == 'hips') _hips.clear();
    _setDraft(updated);
    await _goNext();
  }

  String? _validateStep(String step) {
    switch (step) {
      case 'name':
        if (_draft.preferredName.trim().isEmpty) {
          return t('Enter the name you would like BIL to use.');
        }
      case 'goals':
        if (_draft.goals.isEmpty) return t('Choose at least one goal.');
      case 'activity':
        if (_draft.activity == null) return t('Choose your baseline activity.');
      case 'facts':
        if (_draft.sex == null) {
          return t('Choose the sex used by the calorie equation.');
        }
        if (_draft.birthDate == null ||
            !BilAdultEligibility.isEligibleBirthDate(_draft.birthDate!)) {
          return t('BIL is available only to adults aged 18 or older.');
        }
        if (_draft.countryRegion.trim().length < 2) {
          return t('Enter your country or region.');
        }
      case 'height':
        if (_draft.heightCm == null ||
            _draft.heightCm! < 120 ||
            _draft.heightCm! > 250) {
          return t('Review this information before continuing.');
        }
      case 'currentWeight':
        if (_draft.currentWeightKg == null ||
            _draft.currentWeightKg! < 20 ||
            _draft.currentWeightKg! > 500) {
          return t('Review this information before continuing.');
        }
      case 'targetWeight':
      case 'pace':
      case 'plan':
        final validation = OnboardingPlanCalculator.validate(_draft);
        if (!validation.isValid) return _validationMessage(validation.code!);
      case 'waist':
        if (_draft.waistCm != null &&
            (_draft.waistCm! < 20 || _draft.waistCm! > 300)) {
          return t('Review the optional body measurements, or skip them.');
        }
      case 'neck':
        if (_draft.neckCm != null &&
            (_draft.neckCm! < 20 || _draft.neckCm! > 300)) {
          return t('Review the optional body measurements, or skip them.');
        }
      case 'hips':
        if (_draft.hipsCm != null &&
            (_draft.hipsCm! < 20 || _draft.hipsCm! > 300)) {
          return t('Review the optional body measurements, or skip them.');
        }
      case 'ai':
        if (_draft.remoteAiConsent == OnboardingRemoteAiConsent.unknown) {
          return t('Choose whether to enable cloud AI, or keep it off.');
        }
        if (_draft.remoteAiConsent == OnboardingRemoteAiConsent.granted &&
            _draft.aiFocuses.isEmpty) {
          return t('Choose at least one AI Coach focus.');
        }
      case 'review':
        if (!_draft.estimatesAcknowledged) {
          return t('Acknowledge the estimate limits before finishing.');
        }
    }
    return null;
  }

  String _validationMessage(String code) => switch (code) {
    'loss_target_must_be_lower' => t(
      'Your target must be below your current weight for weight loss.',
    ),
    'gain_target_must_be_higher' => t(
      'Your target must be above your current weight for weight gain.',
    ),
    'maintenance_target_must_match' => t(
      'A maintenance target should match your current weight.',
    ),
    'pace_out_of_range' => t(
      'Choose one of the safe weekly pace options shown.',
    ),
    'waist_must_exceed_neck' || 'circumference_relationship_invalid' => t(
      'Review the optional body measurements, or skip them.',
    ),
    'target_weight_out_of_range' => t('Enter a valid target weight.'),
    _ => t('Review this information before continuing.'),
  };

  Future<void> _complete() async {
    if (_busy) return;
    final message = _validateStep('review');
    if (message != null) {
      setState(() => _inlineError = message);
      return;
    }
    try {
      OnboardingPlanCalculator.calculate(_draft);
    } on Object {
      setState(() => _inlineError = t('BIL could not calculate a safe plan.'));
      return;
    }
    setState(() => _busy = true);
    try {
      // A last-moment persisted choice (for example the estimates checkbox)
      // must finish before the transaction clears the draft. Otherwise its
      // queued write could complete after commit and resurrect onboarding.
      await _draftWrites;
      final service = OnboardingCompletionService(
        database: ref.read(databaseProvider),
        profiles: ref.read(userProfileRepositoryProvider),
        weights: ref.read(weightRepositoryProvider),
        goals: ref.read(goalRepositoryProvider),
        measurements: ref.read(bodyMeasurementRepositoryProvider),
        plans: ref.read(planRepositoryProvider),
        preferences: ref.read(preferencesRepositoryProvider),
        dietaryPreferences: ref.read(dietaryPreferencesRepositoryProvider),
        drafts: ref.read(onboardingDraftRepositoryProvider),
      );
      await service.commit(draft: _draft);
      ref.invalidate(userProfileProvider);
      ref.invalidate(activeGoalProvider);
      ref.invalidate(coachContextSnapshotProvider);
      if (mounted) context.go('/dashboard');
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _inlineError = t(
          'Nothing was changed because BIL could not save the complete setup. Try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: t('Restoring your private setup on this device'),
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_loadFailed) {
      return Scaffold(
        body: Center(
          child: FilledButton.icon(
            onPressed: () {
              setState(() {
                _loaded = false;
                _loadFailed = false;
              });
              unawaited(_load());
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t('Try again')),
          ),
        ),
      );
    }

    final view = _stepView(_stepId);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final navigationBusy = _busy || _transitionBusy || _permissionBusy;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !navigationBusy) unawaited(_goBack());
      },
      child: ModernOnboardingScaffold(
        step: _index,
        totalSteps: _steps.length,
        title: view.title,
        subtitle: view.subtitle,
        artwork: _photoForStep(_stepId),
        body: AnimatedSwitcher(
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: Column(
            key: ValueKey(_stepId),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              view.body,
              if (_inlineError case final error?) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: error),
              ],
            ],
          ),
        ),
        onBack: () => unawaited(_goBack()),
        onNext: () => unawaited(_goNext()),
        onSkip: view.skip,
        nextLabel: _stepId == 'review' ? t('Finish setup') : null,
        nextEnabled: view.nextEnabled,
        busy: navigationBusy,
      ),
    );
  }

  Widget _photoForStep(String step) {
    final (asset, focalAlignment) = switch (step) {
      'name' => (
        'assets/images/onboarding_2026/bil_onboarding_welcome_photo_v1.webp',
        const Alignment(.35, -.28),
      ),
      'goals' || 'activity' || 'pace' => (
        'assets/images/onboarding_2026/bil_onboarding_goals_activity_photo_v1.webp',
        const Alignment(.2, -.38),
      ),
      'facts' => (
        'assets/images/onboarding_2026/bil_onboarding_body_facts_photo_v1.webp',
        const Alignment(.22, -.05),
      ),
      'units' || 'height' => (
        'assets/images/onboarding_2026/bil_onboarding_height_units_photo_v1.webp',
        const Alignment(.15, -.24),
      ),
      'currentWeight' || 'targetWeight' => (
        'assets/images/onboarding_2026/bil_onboarding_weight_photo_v1.webp',
        const Alignment(.15, .55),
      ),
      'waist' => (
        'assets/images/onboarding_2026/bil_onboarding_waist_photo_v1.webp',
        const Alignment(.35, .45),
      ),
      'neck' => (
        'assets/images/onboarding_2026/bil_onboarding_neck_photo_v1.webp',
        const Alignment(.25, .38),
      ),
      'hips' => (
        'assets/images/onboarding_2026/bil_onboarding_hips_photo_v1.webp',
        const Alignment(.3, .62),
      ),
      'plan' => (
        'assets/images/onboarding_2026/bil_onboarding_meal_quick_add_photo_v1.webp',
        const Alignment(.28, .24),
      ),
      'integrations' => (
        'assets/images/onboarding_2026/bil_onboarding_connected_ai_photo_v1.webp',
        const Alignment(.26, .08),
      ),
      'ai' => (bilApprovedAiCoachAsset, Alignment.center),
      _ => (
        'assets/images/onboarding_2026/bil_onboarding_ready_photo_v1.webp',
        const Alignment(.1, .05),
      ),
    };
    return ModernOnboardingPhotoHero(
      key: Key('onboarding-photo-$step'),
      image: AssetImage(asset),
      alignment: focalAlignment,
      height: 120,
    );
  }
}
