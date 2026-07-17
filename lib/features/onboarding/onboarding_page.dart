import 'package:flutter/material.dart';

import 'models/onboarding_data.dart';
import 'widgets/age_step.dart';
import 'widgets/gender_step.dart';
import 'widgets/height_step.dart';
import 'widgets/onboarding_progress.dart';
import 'widgets/welcome_step.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const totalSteps = 8;

  int step = 1;

  final data = OnboardingData();

  final ageController = TextEditingController();
  final heightController = TextEditingController();

  @override
  void dispose() {
    ageController.dispose();
    heightController.dispose();
    super.dispose();
  }

  void next() {
    setState(() {
      step++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Padding(
            key: ValueKey(step),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                OnboardingProgress(
                  step: step,
                  totalSteps: totalSteps,
                ),

                const SizedBox(height: 40),

                Expanded(
                  child: _currentStep(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _currentStep() {
    switch (step) {
      case 1:
        return WelcomeStep(
          onContinue: next,
        );

      case 2:
        return AgeStep(
          controller: ageController,
          onContinue: () {
            if (ageController.text.isEmpty) return;

            data.age = int.parse(ageController.text);

            next();
          },
        );

      case 3:
        return GenderStep(
          gender: data.gender,
          onChanged: (value) {
            setState(() {
              data.gender = value;
            });
          },
          onContinue: next,
        );

      case 4:
        return HeightStep(
          controller: heightController,
          onContinue: () {
            if (heightController.text.isEmpty) return;

            data.height =
                double.parse(heightController.text);

            next();
          },
        );

      default:
        return const Center(
          child: Text(
            'Next step...',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }
  }
}