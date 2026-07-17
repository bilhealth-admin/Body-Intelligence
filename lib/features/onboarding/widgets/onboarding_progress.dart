import 'package:flutter/material.dart';

class OnboardingProgress extends StatelessWidget {
  final int step;
  final int totalSteps;

  const OnboardingProgress({
    super.key,
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = step / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(12),
        ),
        const SizedBox(height: 12),
        Text(
          'Step $step of $totalSteps',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}