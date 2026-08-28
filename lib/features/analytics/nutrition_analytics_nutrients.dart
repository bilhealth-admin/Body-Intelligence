part of 'nutrition_analytics_page.dart';

class _PremiumNutrientDashboard extends StatelessWidget {
  const _PremiumNutrientDashboard({
    required this.preset,
    required this.evidence,
    required this.goals,
  });
  final NutrientDashboardPreset preset;
  final Map<TrackedNutrient, EvidencedNutrientValue> evidence;
  final NutrientDashboardGoalSet goals;

  @override
  Widget build(BuildContext context) {
    final rows = preset.evidenceMetrics.contains(TrackedNutrient.sodium)
        ? <
            ({
              String label,
              double? value,
              double? goal,
              String unit,
              bool minimum,
            })
          >[
            (
              label: _t(context, 'Saturated fat'),
              value: null,
              goal: goals.saturatedFatG,
              unit: 'g',
              minimum: false,
            ),
            (
              label: _t(context, 'Sodium'),
              value: evidence[TrackedNutrient.sodium]?.value,
              goal: goals.sodiumMg,
              unit: 'mg',
              minimum: false,
            ),
            (
              label: _t(context, 'Fiber'),
              value: evidence[TrackedNutrient.fiber]?.value,
              goal: goals.fiberG,
              unit: 'g',
              minimum: true,
            ),
          ]
        : <
            ({
              String label,
              double? value,
              double? goal,
              String unit,
              bool minimum,
            })
          >[
            (
              label: _t(context, 'Carbohydrates'),
              value: evidence[TrackedNutrient.carbohydrates]?.value,
              goal: goals.carbohydratesG,
              unit: 'g',
              minimum: false,
            ),
            (
              label: _t(context, 'Sugar'),
              value: evidence[TrackedNutrient.sugar]?.value,
              goal: goals.sugarG,
              unit: 'g',
              minimum: false,
            ),
            (
              label: _t(context, 'Fiber'),
              value: evidence[TrackedNutrient.fiber]?.value,
              goal: goals.fiberG,
              unit: 'g',
              minimum: true,
            ),
          ];
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t(context, switch (preset) {
                NutrientDashboardPreset.heartHealthy => 'Heart Healthy',
                NutrientDashboardPreset.carbConscious => 'Carb Conscious',
                NutrientDashboardPreset.custom => 'Custom nutrient goals',
                _ => 'Nutrients',
              }),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            for (final row in rows) ...[
              _EvidenceProgressRow(
                label: row.label,
                value: row.value,
                goal: row.goal,
                unit: row.unit,
                minimumGoal: row.minimum,
              ),
              if (row != rows.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _EvidenceProgressRow extends StatelessWidget {
  const _EvidenceProgressRow({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.minimumGoal,
  });
  final String label, unit;
  final double? value;
  final double? goal;
  final bool minimumGoal;

  @override
  Widget build(BuildContext context) {
    final state = NutrientProgressPolicy.evaluate(
      value: value,
      goal: goal ?? 0,
      minimumGoal: minimumGoal,
    );
    final color = switch (state) {
      NutrientProgressState.unknown => Theme.of(context).colorScheme.outline,
      NutrientProgressState.below => const Color(0xFFEF9A23),
      NutrientProgressState.near => const Color(0xFFF2C94C),
      NutrientProgressState.reached => const Color(0xFF269E68),
      NutrientProgressState.exceeded => const Color(0xFFD64B4B),
    };
    final progress = value == null || goal == null || goal! <= 0
        ? 0.0
        : (value! / goal!).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value == null || goal == null || goal! <= 0
                  ? _t(context, 'Unknown')
                  : '${value!.round()} / ${goal!.round()} $unit',
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress, color: color),
      ],
    );
  }
}
