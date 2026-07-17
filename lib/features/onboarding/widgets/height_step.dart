import 'package:flutter/material.dart';

class HeightStep extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onContinue;

  const HeightStep({
    super.key,
    required this.controller,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How tall are you?',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Height is needed to calculate your daily energy needs.',
          style: TextStyle(fontSize: 18),
        ),

        const SizedBox(height: 40),

        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Height (cm)',
            border: OutlineInputBorder(),
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton(
            onPressed: onContinue,
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}