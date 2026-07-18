import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';

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
          Text(
            context.strings.text('Complete your profile'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.strings.text('Age')),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: goalType,
            decoration: InputDecoration(
              labelText: context.strings.text('Goal'),
            ),
            items: [
              DropdownMenuItem(
                value: 'lose',
                child: Text(context.strings.text('Lose weight')),
              ),
              DropdownMenuItem(
                value: 'maintain',
                child: Text(context.strings.text('Maintain weight')),
              ),
              DropdownMenuItem(
                value: 'gain',
                child: Text(context.strings.text('Gain weight')),
              ),
            ],
            onChanged: (value) => onGoalTypeChanged(value ?? 'maintain'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: units,
            decoration: InputDecoration(
              labelText: context.strings.text('Units'),
            ),
            items: [
              DropdownMenuItem(
                value: 'metric',
                child: Text(context.strings.text('Metric (kg, cm)')),
              ),
              DropdownMenuItem(
                value: 'imperial',
                child: Text(context.strings.text('Imperial (lb, in)')),
              ),
            ],
            onChanged: (value) => onUnitsChanged(value ?? 'metric'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: disclaimerAccepted,
            onChanged: (value) => onDisclaimerChanged(value ?? false),
            title: Text(
              context.strings.text(
                'I understand BIL provides general information, not medical advice.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: genderController,
            decoration: InputDecoration(
              labelText: context.strings.text('Gender (male/female)'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: heightController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.strings.text('Height (cm)'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: currentWeightController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.strings.text('Current weight (kg)'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: targetWeightController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.strings.text('Goal weight (kg)'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: activityController,
            decoration: InputDecoration(
              labelText: context.strings.text('Activity level'),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: Text(context.strings.text('Continue')),
            ),
          ),
        ],
      ),
    );
  }
}
