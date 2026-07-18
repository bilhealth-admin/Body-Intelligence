import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../core/units/measurement_units.dart';
import '../../../shared/widgets/wheel_number_field.dart';

class DashboardCheckInCard extends StatefulWidget {
  const DashboardCheckInCard({
    super.key,
    required this.initialWeightKg,
    required this.system,
    required this.onSave,
    required this.onSkip,
  });

  final double initialWeightKg;
  final MeasurementSystem system;
  final Future<void> Function(double weightKg) onSave;
  final Future<void> Function() onSkip;

  @override
  State<DashboardCheckInCard> createState() => _DashboardCheckInCardState();
}

class _DashboardCheckInCardState extends State<DashboardCheckInCard> {
  late double weightKg = widget.initialWeightKg;
  bool saving = false;

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.onSave(weightKg);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> skip() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.onSkip();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = widget.system;
    return Card(
      key: const ValueKey('dashboard-daily-check-in'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.strings.text('Did you weigh yourself today?'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              context.strings.text(
                'A comparable daily check-in improves trend confidence. Normal fluctuations are expected, and skipping is always allowed.',
              ),
            ),
            const SizedBox(height: 12),
            WheelNumberField(
              key: ValueKey(system),
              value: UnitConverter.weightFromKg(weightKg, system),
              minimum: UnitConverter.weightFromKg(20, system),
              maximum: UnitConverter.weightFromKg(350, system),
              step: UnitConverter.weightStep(system),
              decimalPlaces: 1,
              unit: UnitConverter.weightUnit(system),
              label: context.strings.text("Today's weight"),
              onChanged: (value) => setState(
                () => weightKg = UnitConverter.weightToKg(value, system),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: saving ? null : skip,
                  child: Text(context.strings.text('Skip today')),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(context.strings.text('Save check-in')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
