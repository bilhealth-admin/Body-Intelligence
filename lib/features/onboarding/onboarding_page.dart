import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../profile/providers/user_profile_provider.dart';
import 'models/onboarding_data.dart';
import 'widgets/profile_step.dart';
import 'widgets/welcome_step.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int step = 0;
  final data = OnboardingData();

  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final currentWeightController = TextEditingController();
  final targetWeightController = TextEditingController();
  final genderController = TextEditingController();
  final activityController = TextEditingController();
  String goalType = 'maintain';
  String units = 'metric';
  bool disclaimerAccepted = false;
  bool existingProfileLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (existingProfileLoaded) return;
    existingProfileLoaded = true;
    Future<void>(() async {
      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getProfile();
      if (profile == null || !mounted) return;
      ageController.text = profile.age.toString();
      heightController.text = profile.height.toString();
      currentWeightController.text = profile.currentWeight.toString();
      targetWeightController.text = profile.targetWeight.toString();
      genderController.text = profile.gender;
      activityController.text = profile.activityLevel;
      setState(() => disclaimerAccepted = true);
    });
  }

  @override
  void dispose() {
    ageController.dispose();
    heightController.dispose();
    currentWeightController.dispose();
    targetWeightController.dispose();
    genderController.dispose();
    activityController.dispose();
    super.dispose();
  }

  void _next() {
    setState(() {
      step = 1;
    });
  }

  Future<void> _complete() async {
    final age = int.tryParse(ageController.text);
    final height = double.tryParse(heightController.text);
    final currentWeight = double.tryParse(currentWeightController.text);
    final targetWeight = double.tryParse(targetWeightController.text);
    final gender = genderController.text.trim().toLowerCase();
    final activity = activityController.text.trim().toLowerCase();
    final valid =
        age != null &&
        age >= 18 &&
        age <= 120 &&
        height != null &&
        height >= 100 &&
        height <= 250 &&
        currentWeight != null &&
        currentWeight >= 20 &&
        currentWeight <= 500 &&
        targetWeight != null &&
        targetWeight >= 20 &&
        targetWeight <= 500 &&
        const {'male', 'female'}.contains(gender) &&
        const {
          'sedentary',
          'light',
          'moderate',
          'active',
          'very_active',
        }.contains(activity) &&
        disclaimerAccepted;
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete every field with valid values and accept the health disclaimer.',
          ),
        ),
      );
      return;
    }
    final repository = ref.read(userProfileRepositoryProvider);

    await repository.save(
      gender: gender,
      age: age,
      height: height,
      currentWeight: currentWeight,
      targetWeight: targetWeight,
      activityLevel: activity,
      exercises: true,
    );
    final profile = await repository.getProfile();
    if (profile != null) {
      await ref
          .read(goalRepositoryProvider)
          .save(
            profileUuid: profile.uuid,
            type: goalType,
            targetWeight: targetWeight,
          );
    }
    await ref.read(preferencesRepositoryProvider).set('units', units);
    await ref
        .read(preferencesRepositoryProvider)
        .set('healthDisclaimerAccepted', 'true');

    if (!mounted) return;
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: step == 0
                ? WelcomeStep(onContinue: _next)
                : ProfileStep(
                    ageController: ageController,
                    heightController: heightController,
                    currentWeightController: currentWeightController,
                    targetWeightController: targetWeightController,
                    genderController: genderController,
                    activityController: activityController,
                    goalType: goalType,
                    units: units,
                    disclaimerAccepted: disclaimerAccepted,
                    onGoalTypeChanged: (value) =>
                        setState(() => goalType = value),
                    onUnitsChanged: (value) => setState(() => units = value),
                    onDisclaimerChanged: (value) =>
                        setState(() => disclaimerAccepted = value),
                    onContinue: _complete,
                  ),
          ),
        ),
      ),
    );
  }
}
