import 'package:flutter/material.dart';

class GenderStep extends StatelessWidget {
  final String? gender;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;

  const GenderStep({
    super.key,
    required this.gender,
    required this.onChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What is your gender?',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        const Text(
          'This helps BIL Intelligence calculate your body accurately.',
          style: TextStyle(fontSize: 18),
        ),

        const SizedBox(height: 40),

        RadioGroup<String>(
          groupValue: gender,
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
          child: Column(
            children: const [
              Card(
                child: RadioListTile<String>(
                  value: 'Male',
                  title: Text('Male'),
                ),
              ),
              SizedBox(height: 12),
              Card(
                child: RadioListTile<String>(
                  value: 'Female',
                  title: Text('Female'),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton(
            onPressed: gender == null ? null : onContinue,
            child: const Text('Continue', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
