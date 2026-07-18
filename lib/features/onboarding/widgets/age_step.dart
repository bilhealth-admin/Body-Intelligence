import 'package:flutter/material.dart';

class AgeStep extends StatelessWidget {
  final TextEditingController controller;

  final VoidCallback onContinue;

  const AgeStep({
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
          'How old are you?',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        const Text(
          'We use your age to calculate your metabolism.',
          style: TextStyle(fontSize: 18),
        ),

        const SizedBox(height: 40),

        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Age',
            border: OutlineInputBorder(),
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton(
            onPressed: onContinue,
            child: const Text('Continue', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
