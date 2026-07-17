import 'package:flutter/material.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onContinue;

  const WelcomeStep({
    super.key,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),

        const Text(
          'Welcome to BIL',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Your body already knows what it needs.\n\n'
              'BIL Intelligence will calculate everything automatically.\n\n'
              'You only enter your weight and food.',
          style: TextStyle(fontSize: 18),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton(
            onPressed: onContinue,
            child: const Text(
              'Get Started',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}