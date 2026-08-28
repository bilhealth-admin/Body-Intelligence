part of 'nutrition_analytics_page.dart';

class _CaloriesTab extends StatelessWidget {
  const _CaloriesTab({
    required this.meals,
    required this.totals,
    required this.goal,
  });
  final List<MealWithItems> meals;
  final NutritionAnalyticsTotals totals;
  final double? goal;
  @override
  Widget build(BuildContext context) {
    const colors = {
      'breakfast': Color(0xFF315BE8),
      'lunch': Color(0xFF183452),
      'dinner': Color(0xFF087FCE),
      'snack': Color(0xFF18A6E0),
      'other': Color(0xFF78909C),
    };
    return ListView(
      key: const Key('nutrition-calories-tab'),
      padding: const EdgeInsets.all(20),
      children: [
        _DayHeader(),
        const SizedBox(height: 24),
        if (!totals.isComplete(TrackedNutrient.calories))
          _CoverageNotice(
            text: _t(
              context,
              'Calorie total includes evidenced entries only; some entries are unknown.',
            ),
          ),
        for (final type in const [
          'breakfast',
          'lunch',
          'dinner',
          'snack',
          'other',
        ])
          Builder(
            builder: (context) {
              final calories = meals
                  .where((meal) {
                    const primary = {'breakfast', 'lunch', 'dinner', 'snack'};
                    return type == 'other'
                        ? !primary.contains(meal.meal.type)
                        : meal.meal.type == type;
                  })
                  .expand((meal) => meal.items)
                  .where(
                    (item) => NutrientEvidenceMask.contains(
                      item.nutrientEvidenceMask,
                      TrackedNutrient.calories,
                    ),
                  )
                  .fold<double>(0, (sum, item) => sum + item.calories);
              return _DistributionRow(
                label: _t(context, type),
                value: calories,
                total: totals.calories,
                color: colors[type]!,
              );
            },
          ),
        const Divider(height: 40),
        _SummaryRow(
          label: _t(context, 'Total calories'),
          value: totals.calories,
        ),
        _SummaryRow(label: _t(context, 'Goal'), value: goal),
        _SummaryRow(
          label: _t(context, 'Left'),
          value: goal == null ? null : goal! - totals.calories,
        ),
      ],
    );
  }
}

class _NutrientsTab extends StatelessWidget {
  const _NutrientsTab({
    required this.totals,
    required this.targets,
    required this.preset,
    required this.evidence,
    required this.goals,
  });
  final NutritionAnalyticsTotals totals;
  final _NutritionTargets targets;
  final NutrientDashboardPreset preset;
  final Map<TrackedNutrient, EvidencedNutrientValue> evidence;
  final NutrientDashboardGoalSet goals;
  @override
  Widget build(BuildContext context) {
    final rows = [
      (_t(context, 'Protein'), TrackedNutrient.protein, targets.protein, 'g'),
      (
        _t(context, 'Carbohydrates'),
        TrackedNutrient.carbohydrates,
        targets.carbs,
        'g',
      ),
      (_t(context, 'Fiber'), TrackedNutrient.fiber, targets.fiber, 'g'),
      (_t(context, 'Sugar'), TrackedNutrient.sugar, null, 'g'),
      (_t(context, 'Fat'), TrackedNutrient.fat, targets.fats, 'g'),
      (_t(context, 'Sodium'), TrackedNutrient.sodium, null, 'mg'),
      (_t(context, 'Potassium'), TrackedNutrient.potassium, null, 'mg'),
      (_t(context, 'Calcium'), TrackedNutrient.calcium, null, 'mg'),
      (_t(context, 'Magnesium'), TrackedNutrient.magnesium, null, 'mg'),
      (_t(context, 'Phosphorus'), TrackedNutrient.phosphorus, null, 'mg'),
    ];
    return ListView(
      key: const Key('nutrition-nutrients-tab'),
      children: [
        const _DayHeader(),
        if (preset.evidenceMetrics.isNotEmpty)
          _PremiumNutrientDashboard(
            preset: preset,
            evidence: evidence,
            goals: goals,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            _t(context, 'Your recorded nutrients'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _TableHeader(),
        for (final row in rows)
          _NutrientRow(
            label: row.$1,
            total: totals.isKnown(row.$2) ? totals.value(row.$2) : null,
            goal: row.$3,
            unit: row.$4,
          ),
      ],
    );
  }
}

class _CoverageNotice extends StatelessWidget {
  const _CoverageNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
