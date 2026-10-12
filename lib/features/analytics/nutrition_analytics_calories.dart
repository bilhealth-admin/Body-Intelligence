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
                  .expand(
                    (meal) => meal.items.map(
                      (item) => MealFoodEvidence.read(
                        item,
                        ownerKey: meal.ownerKey,
                      ).value(TrackedNutrient.calories),
                    ),
                  )
                  .whereType<double>()
                  .fold<double>(0, (sum, value) => sum + value);
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

class _NutrientsTab extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    double? nutrientGoal(String key) =>
        ref.watch(dashboardNutrientGoalProvider(key)).value;
    final rows = [
      (_t(context, 'Protein'), TrackedNutrient.protein, targets.protein, 'g'),
      (
        _t(context, 'Carbohydrates'),
        TrackedNutrient.carbohydrates,
        targets.carbs,
        'g',
      ),
      (
        _t(context, 'Fiber'),
        TrackedNutrient.fiber,
        nutrientGoal('goal.fiber'),
        'g',
      ),
      (
        _t(context, 'Sugar'),
        TrackedNutrient.sugar,
        nutrientGoal('goal.sugar'),
        'g',
      ),
      (_t(context, 'Fat'), TrackedNutrient.fat, targets.fats, 'g'),
      (
        _t(context, 'Sodium'),
        TrackedNutrient.sodium,
        nutrientGoal('goal.sodium'),
        'mg',
      ),
      (
        _t(context, 'Potassium'),
        TrackedNutrient.potassium,
        nutrientGoal('goal.potassium'),
        'mg',
      ),
      (
        _t(context, 'Calcium'),
        TrackedNutrient.calcium,
        nutrientGoal('goal.calciumMg'),
        'mg',
      ),
      (
        _t(context, 'Magnesium'),
        TrackedNutrient.magnesium,
        nutrientGoal('goal.magnesium'),
        'mg',
      ),
      (
        _t(context, 'Phosphorus'),
        TrackedNutrient.phosphorus,
        nutrientGoal('goal.phosphorus'),
        'mg',
      ),
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
        if (TrackedNutrient.values.any(
          (n) => totals.isKnown(n) && !totals.isComplete(n),
        ))
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'المجموع الجزئي يعتمد على السجلات المعروفة فقط. القيم الناقصة لا تُحسب صفرًا.'
                  : 'Partial totals include known records only. Missing values are not zero.',
            ),
          ),
        _TableHeader(),
        for (final row in rows)
          _NutrientRow(
            label: totals.isComplete(row.$2) ? row.$1 : '${row.$1} *',
            total: totals.isKnown(row.$2) ? totals.value(row.$2) : null,
            goal: row.$3,
            unit: row.$4,
          ),
        for (final extra in const [
          (FoodNutrient.iron, 'Iron', 'goal.ironMg'),
          (FoodNutrient.vitaminC, 'Vitamin C', 'goal.vitaminCMg'),
        ])
          _NutrientRow(
            label:
                '${_t(context, extra.$2)}${totals.fullComplete(extra.$1) ? '' : ' *'}',
            total: totals.fullTotal(extra.$1),
            goal: nutrientGoal(extra.$3),
            unit: 'mg',
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'المرجع اليومي العام ليس تحليلًا طبيًا. النجمة تعني بيانات غير مكتملة. الحديد وفيتامين C يظهران عند وجودهما في لقطة الطعام المسجلة؛ لن نستخدم طعامًا عُدّل لاحقًا لتغيير يوم سابق.'
                : 'Daily references are not laboratory ranges. An asterisk means incomplete evidence. Iron and vitamin C require a recorded food snapshot; later food edits never rewrite historical days.',
          ),
        ),
        for (final extra in const [
          (
            FoodNutrient.saturatedFat,
            'Saturated fat',
            'goal.saturatedFat',
            'g',
          ),
          (
            FoodNutrient.polyunsaturatedFat,
            'Polyunsaturated fat',
            'goal.polyunsaturatedFat',
            'g',
          ),
          (
            FoodNutrient.monounsaturatedFat,
            'Monounsaturated fat',
            'goal.monounsaturatedFat',
            'g',
          ),
          (FoodNutrient.transFat, 'Trans fat', 'goal.transFat', 'g'),
          (FoodNutrient.cholesterol, 'Cholesterol', 'goal.cholesterol', 'mg'),
          (FoodNutrient.vitaminA, 'Vitamin A', 'goal.vitaminAMcg', 'mcg RAE'),
        ])
          _NutrientRow(
            label:
                '${_t(context, extra.$2)}${totals.fullComplete(extra.$1) ? '' : ' *'}',
            total: totals.fullTotal(extra.$1),
            goal: nutrientGoal(extra.$3),
            unit: extra.$4,
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'تُجمع أنواع الدهون والكوليسترول وفيتامين أ من لقطة الطعام المسجلة فقط. المغذّي المفقود يبقى غير متاح، والصفر الموثق يبقى صفرًا.'
                : 'Fat subtypes, cholesterol and vitamin A use the recorded food snapshot. Missing values stay unavailable; a recorded zero stays zero.',
          ),
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
