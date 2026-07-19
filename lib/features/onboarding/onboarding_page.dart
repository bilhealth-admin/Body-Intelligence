import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
import '../../core/units/measurement_units.dart';
import '../profile/providers/user_profile_provider.dart';
import 'models/onboarding_draft.dart';
import 'widgets/profile_step.dart';
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
  final profileScrollController = ScrollController();
  double heightCm = 155;
  double currentWeightKg = 60;
  double targetWeightKg = 60;
  double? waistCm;
  double? neckCm;
  String? gender;
  String? activity;
  String goalType = 'maintain';
  MeasurementSystem system = MeasurementSystem.metric;
  bool disclaimerAccepted = false;
  bool existingProfileLoaded = false;
  bool draftLoaded = false;
  bool draftRestored = false;
  Map<String, String> errors = const {};

  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';
  String message(String en, String ar) => isArabic ? ar : en;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (existingProfileLoaded) return;
    existingProfileLoaded = true;
    Future<void>(() async {
      final preferences = ref.read(preferencesRepositoryProvider);
      final savedUnits = await preferences.get('units');
      final savedRegion = await preferences.get('countryRegion');
      final draft = await ref.read(onboardingDraftRepositoryProvider).load();
      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getProfile();
      if (!mounted) return;
      setState(() {
        if (profile != null) {
          step = 1;
          ageController.text = profile.age.toString();
          heightCm = profile.height;
          currentWeightKg = profile.currentWeight;
          targetWeightKg = profile.targetWeight;
          waistCm = profile.waist;
          neckCm = profile.neck;
          gender = profile.gender;
          activity = profile.activityLevel;
          goalType = profile.targetWeight < profile.currentWeight
              ? 'lose'
              : profile.targetWeight > profile.currentWeight
              ? 'gain'
              : 'maintain';
          disclaimerAccepted = true;
        } else if (draft != null) {
          draftRestored = true;
          step = draft.step;
          ageController.text = draft.age;
          heightCm = draft.heightCm;
          currentWeightKg = draft.currentWeightKg;
          targetWeightKg = draft.targetWeightKg;
          waistCm = draft.waistCm;
          neckCm = draft.neckCm;
          regionController.text = draft.region;
          gender = draft.gender;
          activity = draft.activity;
          goalType = draft.goalType;
          system = draft.system;
          disclaimerAccepted = draft.disclaimerAccepted;
        } else {
          system = savedUnits == 'imperial'
              ? MeasurementSystem.imperial
              : MeasurementSystem.metric;
          regionController.text = savedRegion ?? '';
        }
        draftLoaded = true;
      });
    });
  }

  @override
  void dispose() {
    ageController.dispose();
    regionController.dispose();
    profileScrollController.dispose();
    super.dispose();
  }

  Map<String, String> validate() {
    final next = <String, String>{};
    final age = int.tryParse(ageController.text);
    if (age == null || age < 18 || age > 120) {
      next['age'] = message(
        'Enter an age from 18 to 120.',
        'أدخل عمرًا من ١٨ إلى ١٢٠.',
      );
    }
    if (gender == null) {
      next['gender'] = message(
        'Select biological sex.',
        'اختر الجنس البيولوجي.',
      );
    }
    if (activity == null) {
      next['activity'] = message(
        'Select an activity level.',
        'اختر مستوى النشاط.',
      );
    }
    if (heightCm < 100 || heightCm > 250) {
      next['height'] = message(
        'Height must be between 100 and 250 cm.',
        'يجب أن يكون الطول بين ١٠٠ و٢٥٠ سم.',
      );
    }
    if (currentWeightKg < 20 || currentWeightKg > 350) {
      next['currentWeight'] = message(
        'Weight must be between 20 and 350 kg.',
        'يجب أن يكون الوزن بين ٢٠ و٣٥٠ كجم.',
      );
    }
    if (targetWeightKg < 20 || targetWeightKg > 350) {
      next['targetWeight'] = message(
        'Goal weight must be between 20 and 350 kg.',
        'يجب أن يكون الوزن المستهدف بين ٢٠ و٣٥٠ كجم.',
      );
    } else if (goalType == 'lose' && targetWeightKg >= currentWeightKg) {
      next['targetWeight'] = message(
        'For weight loss, choose a goal below your current weight.',
        'لخسارة الوزن، اختر هدفًا أقل من وزنك الحالي.',
      );
    } else if (goalType == 'gain' && targetWeightKg <= currentWeightKg) {
      next['targetWeight'] = message(
        'For weight gain, choose a goal above your current weight.',
        'لزيادة الوزن، اختر هدفًا أعلى من وزنك الحالي.',
      );
    } else if (goalType == 'maintain' &&
        (targetWeightKg - currentWeightKg).abs() > 2) {
      next['targetWeight'] = message(
        'A maintenance goal should remain within 2 kg of current weight.',
        'هدف الحفاظ يجب أن يكون ضمن ٢ كجم من الوزن الحالي.',
      );
    }
    if (!disclaimerAccepted) {
      next['disclaimer'] = message(
        'Accept the health disclaimer to continue.',
        'وافق على إخلاء المسؤولية الصحية للمتابعة.',
      );
    }
    return next;
  }

  Future<void> complete() async {
    final nextErrors = validate();
    setState(() => errors = nextErrors);
    if (nextErrors.isNotEmpty) {
      if (profileScrollController.hasClients) {
        await profileScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    final repository = ref.read(userProfileRepositoryProvider);
    await repository.save(
      gender: gender!,
      age: int.parse(ageController.text),
      height: heightCm,
      currentWeight: currentWeightKg,
      targetWeight: targetWeightKg,
      activityLevel: activity!,
      exercises: activity != 'sedentary',
      waist: waistCm,
      neck: neckCm,
    );
    final profile = await repository.getProfile();
    if (profile != null) {
      await ref
          .read(goalRepositoryProvider)
          .save(
            profileUuid: profile.uuid,
            type: goalType,
            targetWeight: targetWeightKg,
          );
    }
    final preferences = ref.read(preferencesRepositoryProvider);
    await preferences.set('units', system.name);
    await preferences.set('healthDisclaimerAccepted', 'true');
    final region = regionController.text.trim();
    if (region.isEmpty) {
      await preferences.remove('countryRegion');
    } else {
      await preferences.set('countryRegion', region);
    }
    final now = DateTime.now();
    await preferences.set('timezoneName', now.timeZoneName);
    await preferences.set(
      'timezoneOffsetMinutes',
      now.timeZoneOffset.inMinutes.toString(),
    );
    await ref.read(onboardingDraftRepositoryProvider).clear();
    if (mounted) context.go('/dashboard');
  }

  OnboardingDraft get draft => OnboardingDraft(
    step: step,
    age: ageController.text,
    heightCm: heightCm,
    currentWeightKg: currentWeightKg,
    targetWeightKg: targetWeightKg,
    waistCm: waistCm,
    neckCm: neckCm,
    region: regionController.text,
    gender: gender,
    activity: activity,
    goalType: goalType,
    system: system,
    disclaimerAccepted: disclaimerAccepted,
  );

  void persistDraft() {
    if (!draftLoaded) return;
    ref.read(onboardingDraftRepositoryProvider).save(draft);
  }

  void update(VoidCallback change) {
    setState(change);
    persistDraft();
  }

  void updateSystem(MeasurementSystem value) {
    update(() {
      system = value;
      errors = {...errors}
        ..remove('height')
        ..remove('currentWeight')
        ..remove('targetWeight');
    });
    ref.read(preferencesRepositoryProvider).set('units', value.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: !draftLoaded
              ? Center(
                  child: Semantics(
                    label: context.strings.text(
                      'Restoring your private setup on this device',
                    ),
                    child: const CircularProgressIndicator(),
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: step == 0
                      ? WelcomeStep(
                          key: const ValueKey('welcome'),
                          onContinue: () => update(() => step = 1),
                        )
                      : ProfileStep(
                          key: const ValueKey('profile'),
                          ageController: ageController,
                          heightCm: heightCm,
                          currentWeightKg: currentWeightKg,
                          targetWeightKg: targetWeightKg,
                          waistCm: waistCm,
                          neckCm: neckCm,
                          regionController: regionController,
                          gender: gender,
                          activity: activity,
                          goalType: goalType,
                          system: system,
                          disclaimerAccepted: disclaimerAccepted,
                          draftRestored: draftRestored,
                          errors: errors,
                          onAgeChanged: (_) => persistDraft(),
                          onRegionChanged: (_) => persistDraft(),
                          onHeightChanged: (value) =>
                              update(() => heightCm = value),
                          onCurrentWeightChanged: (value) =>
                              update(() => currentWeightKg = value),
                          onTargetWeightChanged: (value) =>
                              update(() => targetWeightKg = value),
                          onWaistChanged: (value) =>
                              update(() => waistCm = value),
                          onNeckChanged: (value) =>
                              update(() => neckCm = value),
                          onGenderChanged: (value) =>
                              update(() => gender = value),
                          onActivityChanged: (value) =>
                              update(() => activity = value),
                          onGoalTypeChanged: (value) =>
                              update(() => goalType = value),
                          onSystemChanged: updateSystem,
                          onDisclaimerChanged: (value) =>
                              update(() => disclaimerAccepted = value),
                          onContinue: complete,
                          scrollController: profileScrollController,
                        ),
                ),
        ),
      ),
    );
  }
}
