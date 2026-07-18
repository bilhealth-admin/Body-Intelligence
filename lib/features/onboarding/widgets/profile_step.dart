import 'package:flutter/material.dart';

class ProfileStep extends StatelessWidget {
  const ProfileStep({
    super.key,
    required this.ageController,
    required this.heightController,
    required this.currentWeightController,
    required this.targetWeightController,
    required this.genderController,
    required this.activityController,
    required this.goalType,
    required this.units,
    required this.disclaimerAccepted,
    required this.onGoalTypeChanged,
    required this.onUnitsChanged,
    required this.onDisclaimerChanged,
    required this.onContinue,
  });

  final TextEditingController ageController;
  final TextEditingController heightController;
  final TextEditingController currentWeightController;
  final TextEditingController targetWeightController;
  final TextEditingController genderController;
  final TextEditingController activityController;
  final String goalType;
  final String units;
  final bool disclaimerAccepted;
  final ValueChanged<String> onGoalTypeChanged;
  final ValueChanged<String> onUnitsChanged;
  final ValueChanged<bool> onDisclaimerChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complete your profile',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: goalType,
            decoration: const InputDecoration(labelText: 'Goal'),
            items: const [
              DropdownMenuItem(value: 'lose', child: Text('Lose weight')),
              DropdownMenuItem(
                value: 'maintain',
                child: Text('Maintain weight'),
              ),
              DropdownMenuItem(value: 'gain', child: Text('Gain weight')),
            ],
            onChanged: (value) => onGoalTypeChanged(value ?? 'maintain'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: units,
            decoration: const InputDecoration(labelText: 'Units'),
            items: const [
              DropdownMenuItem(value: 'metric', child: Text('Metric (kg, cm)')),
              DropdownMenuItem(
                value: 'imperial',
                child: Text('Imperial (lb, in)'),
              ),
            ],
            onChanged: (value) => onUnitsChanged(value ?? 'metric'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: disclaimerAccepted,
            onChanged: (value) => onDisclaimerChanged(value ?? false),
            title: const Text(
              'I understand BIL provides general information, not medical advice.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: genderController,
            decoration: const InputDecoration(
              labelText: 'Gender (male/female)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: heightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Height (cm)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: currentWeightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Current weight (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: targetWeightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Goal weight (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: activityController,
            decoration: const InputDecoration(labelText: 'Activity level'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
