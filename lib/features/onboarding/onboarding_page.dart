import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../core/units/measurement_units.dart';
import '../../data/database/date_keys.dart';
import '../../engine/body_model_engine.dart';
import '../../engine/body_profile.dart';
import '../intelligence_center/services/coach_context_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'bil_flagship_onboarding.dart';
import 'domain/adult_eligibility.dart';
import 'onboarding_locale_copy.dart';
import 'widgets/welcome_step.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int step = 0;
  final ageController = TextEditingController();
  final regionController = TextEditingController();

  double heightCm = 155;
  double currentWeightKg = 60;
  double targetWeightKg = 60;
  double? waistCm;
  double? neckCm;
  double? hipsCm;
  String? gender;
  String? activity;
  String goalType = 'maintain';
  MeasurementSystem system = MeasurementSystem.metric;

  bool existingProfileLoaded = false;
  bool draftLoaded = false;
  bool draftRestored = false;
  bool profileRestored = false;
  bool loadFailed = false;
  bool saving = false;

  bool get isArabic =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

  String tr(String english, String arabic) =>
      onboardingText(context, english, arabic);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (existingProfileLoaded) return;
    existingProfileLoaded = true;
    loadInitialState();
  }

  Future<void> loadInitialState() async {
    try {
      final preferences = ref.read(preferencesRepositoryProvider);
      final savedUnits = await preferences.get('units');
      final savedRegion = await preferences.get('countryRegion');
      final savedDraft = await ref
          .read(onboardingDraftRepositoryProvider)
          .load();
      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getProfile();
      final latestMeasurements = await ref
          .read(bodyMeasurementRepositoryProvider)
          .getLatest();

      if (!mounted) return;
      setState(() {
        if (profile != null) {
          profileRestored = true;
          step = 0;
          ageController.text = profile.age.toString();
          heightCm = profile.height;
          currentWeightKg = profile.currentWeight;
          targetWeightKg = profile.targetWeight;
          waistCm = latestMeasurements?.waistCm ?? profile.waist;
          neckCm = latestMeasurements?.neckCm ?? profile.neck;
          hipsCm = latestMeasurements?.hipsCm;
          gender = profile.gender;
          activity = profile.activityLevel;
          goalType = profile.targetWeight < profile.currentWeight
              ? 'lose'
              : profile.targetWeight > profile.currentWeight
              ? 'gain'
              : 'maintain';
        } else if (savedDraft != null) {
          draftRestored = true;
          step = 0;
          ageController.text = savedDraft.age;
          heightCm = savedDraft.heightCm;
          currentWeightKg = savedDraft.currentWeightKg;
          targetWeightKg = savedDraft.targetWeightKg;
          waistCm = savedDraft.waistCm;
          neckCm = savedDraft.neckCm;
          hipsCm = savedDraft.hipsCm;
          regionController.text = savedDraft.region;
          gender = savedDraft.gender;
          activity = savedDraft.activity;
          goalType = savedDraft.goalType;
          system = savedDraft.system;
        } else {
          system = savedUnits == 'imperial'
              ? MeasurementSystem.imperial
              : MeasurementSystem.metric;
          regionController.text = savedRegion ?? '';
        }
        draftLoaded = true;
        loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        draftLoaded = true;
        loadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    ageController.dispose();
    regionController.dispose();
    super.dispose();
  }

  int _ageFromBirthDate(DateTime birthDate) {
    return BilAdultEligibility.ageOn(birthDate);
  }

  BilOnboardingDraft _initialFlagshipDraft() {
    final age = int.tryParse(ageController.text);
    final now = DateTime.now();

    return BilOnboardingDraft()
      ..birthDate = age == null ? null : DateTime(now.year - age, 1, 1)
      ..sex = gender == 'female' ? BilSex.female : BilSex.male
      ..units = system == MeasurementSystem.imperial
          ? BilUnits.imperial
          : BilUnits.metric
      ..goal = switch (goalType) {
        'gain' => BilGoal.buildMuscle,
        'maintain' => BilGoal.maintain,
        _ => BilGoal.loseFat,
      }
      ..activity = switch (activity) {
        'sedentary' => BilActivity.low,
        'light' => BilActivity.light,
        'active' => BilActivity.high,
        'veryActive' => BilActivity.veryHigh,
        _ => BilActivity.moderate,
      }
      ..sexConfirmed = draftRestored || profileRestored
      ..goalConfirmed = draftRestored || profileRestored
      ..activityConfirmed = draftRestored || profileRestored
      ..weight = (draftRestored || profileRestored)
          ? (system == MeasurementSystem.metric
                ? currentWeightKg
                : currentWeightKg * BilOnboardingDraft.poundsPerKilogram)
          : null
      ..height = (draftRestored || profileRestored)
          ? (system == MeasurementSystem.metric
                ? heightCm
                : heightCm / BilOnboardingDraft.centimetersPerInch)
          : null
      ..waist = (draftRestored || profileRestored)
          ? _displayLength(waistCm)
          : null
      ..neck = (draftRestored || profileRestored)
          ? _displayLength(neckCm)
          : null
      ..hips = (draftRestored || profileRestored)
          ? _displayLength(hipsCm)
          : null;
  }

  double? _displayLength(double? centimeters) => centimeters == null
      ? null
      : system == MeasurementSystem.metric
      ? centimeters
      : centimeters / BilOnboardingDraft.centimetersPerInch;

  Future<BilInitialPlan> _calculatePlan(BilOnboardingDraft draft) async {
    final birthDate = draft.birthDate;
    final weight = draft.weightKg;
    final height = draft.heightCm;

    if (birthDate == null || weight == null || height == null) {
      throw StateError('Missing required body calibration values.');
    }
    if (!BilAdultEligibility.isEligibleBirthDate(birthDate)) {
      throw StateError('adult_eligibility_required');
    }

    final age = _ageFromBirthDate(birthDate);
    final model = BodyModelEngine.calculate(
      BodyProfile(
        age: age,
        gender: draft.sex == BilSex.male ? 'male' : 'female',
        height: height,
        weight: weight,
        targetWeight: _suggestedTargetWeight(draft),
        activityLevel: _activityValue(draft.activity),
        exercises: draft.activity != BilActivity.low,
        goalType: _goalValue(draft.goal),
        waistCm: draft.waistCm,
        neckCm: draft.neckCm,
        hipCm: draft.hipsCm,
      ),
    );

    final weeklyPace = switch (draft.goal) {
      BilGoal.loseFat => -0.4,
      BilGoal.maintain => 0.0,
      BilGoal.buildMuscle => 0.2,
    };

    return BilInitialPlan(
      calories: model.targets.calories,
      protein: model.targets.protein,
      carbs: model.targets.carbs,
      fat: model.targets.fats,
      weeklyPace: weeklyPace,
    );
  }

  String _activityValue(BilActivity value) {
    return switch (value) {
      BilActivity.low => 'sedentary',
      BilActivity.light => 'light',
      BilActivity.moderate => 'moderate',
      BilActivity.high => 'active',
      BilActivity.veryHigh => 'veryActive',
    };
  }

  String _goalValue(BilGoal value) {
    return switch (value) {
      BilGoal.loseFat => 'lose',
      BilGoal.maintain => 'maintain',
      BilGoal.buildMuscle => 'gain',
    };
  }

  double _suggestedTargetWeight(BilOnboardingDraft draft) {
    final weight = draft.weightKg!;
    return switch (draft.goal) {
      BilGoal.loseFat => weight * .90,
      BilGoal.maintain => weight,
      BilGoal.buildMuscle => weight * 1.05,
    };
  }

  Future<bool> _confirmHealthDisclaimer() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Important health information', 'معلومة صحية مهمة')),
        content: Text(
          tr(
            'BIL provides educational, personalized estimates and does not replace diagnosis or medical care. By continuing, you acknowledge that final medical decisions remain with you and your clinician.',
            'BIL يقدم تقديرات تعليمية وشخصية ولا يستبدل التشخيص أو الرعاية الطبية. بالمتابعة فإنك تقر بأن القرار الطبي النهائي يعود لك ولطبيبك.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Back', 'رجوع')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Accept & continue', 'أوافق وأتابع')),
          ),
        ],
      ),
    );
    return accepted ?? false;
  }

  Future<void> _saveAndComplete(
    BilOnboardingDraft draft,
    BilInitialPlan plan,
  ) async {
    if (saving) return;
    final birthDate = draft.birthDate;
    if (birthDate == null ||
        !BilAdultEligibility.isEligibleBirthDate(birthDate)) {
      return;
    }
    final accepted = await _confirmHealthDisclaimer();
    if (!accepted || !mounted) return;

    setState(() => saving = true);
    try {
      final age = _ageFromBirthDate(birthDate);
      final currentWeight = draft.weightKg!;
      final targetWeight = _suggestedTargetWeight(draft);
      final activityValue = _activityValue(draft.activity);
      final goalValue = _goalValue(draft.goal);

      final repository = ref.read(userProfileRepositoryProvider);
      await repository.save(
        gender: draft.sex == BilSex.male ? 'male' : 'female',
        age: age,
        height: draft.heightCm!,
        currentWeight: currentWeight,
        targetWeight: targetWeight,
        activityLevel: activityValue,
        exercises: activityValue != 'sedentary',
        waist: draft.waistCm,
        neck: draft.neckCm,
      );

      final profile = await repository.getProfile();
      if (profile != null) {
        await ref
            .read(goalRepositoryProvider)
            .save(
              profileUuid: profile.uuid,
              type: goalValue,
              targetWeight: targetWeight,
            );
      }

      final measurementRepository = ref.read(bodyMeasurementRepositoryProvider);
      final now = DateTime.now();
      final latestMeasurement = await measurementRepository.getLatest();
      final sameDay = latestMeasurement?.dayKey == dayKeyFor(now);
      await measurementRepository.saveForDay(
        date: now,
        neckCm: draft.neckCm,
        waistCm: draft.waistCm,
        hipsCm: draft.hipsCm,
        chestCm: sameDay ? latestMeasurement?.chestCm : null,
        armCm: sameDay ? latestMeasurement?.armCm : null,
        thighCm: sameDay ? latestMeasurement?.thighCm : null,
      );

      final preferences = ref.read(preferencesRepositoryProvider);
      await preferences.set(
        'units',
        draft.units == BilUnits.imperial ? 'imperial' : 'metric',
      );
      await preferences.set('healthDisclaimerAccepted', 'true');
      await preferences.set('profileDateOfBirth', birthDate.toIso8601String());

      final region = regionController.text.trim();
      if (region.isEmpty) {
        await preferences.remove('countryRegion');
      } else {
        await preferences.set('countryRegion', region);
      }

      await preferences.set('timezoneName', now.timeZoneName);
      await preferences.set(
        'timezoneOffsetMinutes',
        now.timeZoneOffset.inMinutes.toString(),
      );
      await preferences.set('firstValueHandoffPending', 'false');
      await preferences.set('forceOnboarding', 'false');

      // Establish the versioned dietary contract during first-run setup even
      // when the user keeps the neutral default. Existing restored choices
      // are preserved instead of being reset by re-onboarding.
      final dietaryRepository = ref.read(dietaryPreferencesRepositoryProvider);
      await dietaryRepository.save(await dietaryRepository.read());

      await ref.read(onboardingDraftRepositoryProvider).clear();

      // Weight, sex and activity already drive the local plan above. Refresh
      // the cached bounded Coach context as part of the same committed setup
      // so the next AI turn sees the identical profile evidence.
      ref.invalidate(coachContextSnapshotProvider);

      if (mounted) context.go('/dashboard');
    } catch (error, stack) {
      debugPrint('Failed to save flagship onboarding: $error\n$stack');
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Could not save the profile on this device. No data was uploaded.',
              'تعذر حفظ الملف على هذا الجهاز. لم يتم رفع أي بيانات.',
            ),
          ),
        ),
      );
    }
  }

  Widget _loadingView() {
    return Center(
      child: Semantics(
        label: context.strings.text(
          'Restoring your private setup on this device',
        ),
        child: const CircularProgressIndicator(),
      ),
    );
  }

  Widget _loadFailureView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storage_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              context.strings.text('Could not restore your local setup'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  draftLoaded = false;
                  loadFailed = false;
                });
                loadInitialState();
              },
              icon: const Icon(Icons.refresh),
              label: Text(context.strings.text('Try again')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!draftLoaded) {
      return Scaffold(body: SafeArea(child: _loadingView()));
    }

    if (loadFailed) {
      return Scaffold(body: SafeArea(child: _loadFailureView()));
    }

    final content = step == 0
        ? Scaffold(
            key: const ValueKey('welcome'),
            body: SafeArea(
              child: WelcomeStep(onContinue: () => setState(() => step = 1)),
            ),
          )
        : BilFlagshipOnboarding(
            key: ValueKey('flagship-${draftRestored ? 'restored' : 'new'}'),
            showWelcome: false,
            initialDraft: _initialFlagshipDraft(),
            onExitToWelcome: () => setState(() => step = 0),
            calculatePlan: _calculatePlan,
            onComplete: _saveAndComplete,
          );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(.035, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: content,
    );
  }
}
