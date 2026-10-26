part of 'daily_log_summary_widgets.dart';

abstract final class DailyMealMacroPalette {
  static const light = [
    Color(0xFF0A8F88),
    Color(0xFF6F1096),
    Color(0xFFC56A00),
  ];
  static const dark = [Color(0xFF63D5C4), Color(0xFFC795EE), Color(0xFFFFC16F)];
  static List<Color> forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

class DailyMealDetailSummary extends StatelessWidget {
  const DailyMealDetailSummary({
    super.key,
    required this.meal,
    this.calorieGoal,
    this.carbsGoal,
    this.proteinGoal,
    this.fatGoal,
    this.macroDisplay,
    this.mealGoal,
    this.mealCalorieGoal,
    this.onEditMealGoal,
  });

  final MealWithItems? meal;
  final double? calorieGoal;
  final double? carbsGoal;
  final double? proteinGoal;
  final double? fatGoal;
  final MealMacroDisplay? macroDisplay;
  final NutritionGoalTarget? mealGoal;
  final double? mealCalorieGoal;
  final VoidCallback? onEditMealGoal;

  @override
  Widget build(BuildContext context) {
    final items = meal?.items ?? const <MealItem>[];
    final evidence = DailyLogNutritionEvidence.forItems(
      items,
      ownerKey: meal?.ownerKey,
    );
    double? total(TrackedNutrient nutrient) =>
        evidence.total(nutrient, emptyAsZero: true);
    final calories = total(TrackedNutrient.calories);
    final protein = total(TrackedNutrient.protein);
    final carbs = total(TrackedNutrient.carbohydrates);
    final fat = total(TrackedNutrient.fat);
    final mealCarbsGoal = mealGoal?.carbsGrams ?? carbsGoal;
    final mealFatGoal = mealGoal?.fatGrams ?? fatGoal;
    final mealProteinGoal = mealGoal?.proteinGrams ?? proteinGoal;
    double targetProgress(double? consumed, double? goal) =>
        consumed == null || goal == null || !goal.isFinite || goal <= 0
        ? 0
        : (consumed / goal).clamp(0.0, 1.0).toDouble();
    final sodium = evidence.total(TrackedNutrient.sodium);
    final potassium = evidence.total(TrackedNutrient.potassium);
    final magnesium = evidence.total(TrackedNutrient.magnesium);
    final scheme = Theme.of(context).colorScheme;
    final macroColors = DailyMealMacroPalette.forBrightness(scheme.brightness);
    return Container(
      key: const Key('daily-meal-detail-summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final calorieRing = DailyLogCalorieMacroRing(
            calories: calories,
            calorieGoal: mealGoal?.calories ?? mealCalorieGoal ?? calorieGoal,
            carbs: carbs,
            fat: fat,
            protein: protein,
            dimension: 136,
            mealDetailStyle: true,
            showGoal: false,
          );
          final macroDials = Row(
            key: const Key('daily-meal-detail-macros'),
            children: [
              Expanded(
                child: _MealMacroDial(
                  key: const Key('daily-meal-macro-carbs'),
                  label: _summaryText(context, 'carbs'),
                  grams: carbs,
                  goalGrams: mealCarbsGoal,
                  progress: targetProgress(carbs, mealCarbsGoal),
                  displayPercent:
                      macroDisplay?.mode == MealMacroDisplayMode.percent,
                  color: macroColors[0],
                ),
              ),
              Expanded(
                child: _MealMacroDial(
                  key: const Key('daily-meal-macro-fat'),
                  label: _summaryText(context, 'fat'),
                  grams: fat,
                  goalGrams: mealFatGoal,
                  progress: targetProgress(fat, mealFatGoal),
                  displayPercent:
                      macroDisplay?.mode == MealMacroDisplayMode.percent,
                  color: macroColors[1],
                ),
              ),
              Expanded(
                child: _MealMacroDial(
                  key: const Key('daily-meal-macro-protein'),
                  label: _summaryText(context, 'proteinShort'),
                  grams: protein,
                  goalGrams: mealProteinGoal,
                  progress: targetProgress(protein, mealProteinGoal),
                  displayPercent:
                      macroDisplay?.mode == MealMacroDisplayMode.percent,
                  color: macroColors[2],
                ),
              ),
            ],
          );
          final minerals = IntrinsicHeight(
            child: Row(
              key: const Key('daily-meal-detail-minerals'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final metric in [
                  (context.strings.text('Sodium'), sodium),
                  (context.strings.text('Potassium'), potassium),
                  (context.strings.text('Magnesium'), magnesium),
                ]) ...[
                  if (metric.$1 != context.strings.text('Sodium'))
                    const SizedBox(width: 6),
                  Expanded(
                    child: NutrientMetric(
                      label: metric.$1,
                      value: metric.$2,
                      unit: 'mg',
                      compact: true,
                      unknownAsDash: true,
                    ),
                  ),
                ],
              ],
            ),
          );
          final premiumNutrition = PremiumNutritionFieldsGroup(
            key: const Key('daily-meal-detail-premium-group'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  if (macroDisplay?.enabled ?? true) ...[
                    macroDials,
                    const SizedBox(height: 14),
                  ],
                  minerals,
                ],
              ),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: calorieRing),
              const SizedBox(height: 14),
              premiumNutrition,
              const SizedBox(height: 12),
              _MealGoalSummary(
                goal: mealGoal,
                calorieOnly: mealCalorieGoal,
                onEdit: onEditMealGoal,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MealMacroDial extends StatelessWidget {
  const _MealMacroDial({
    super.key,
    required this.label,
    required this.grams,
    required this.goalGrams,
    required this.progress,
    required this.color,
    required this.displayPercent,
  });

  final String label;
  final double? grams;
  final double? goalGrams;
  final double progress;
  final Color color;
  final bool displayPercent;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goalGrams != null && goalGrams!.isFinite && goalGrams! > 0;
    final displayValue = grams == null
        ? '—'
        : displayPercent
        ? hasGoal
              ? '${(grams! / goalGrams! * 100).round()}%'
              : '—'
        : '${formatDiaryMacroGrams(grams!)} g';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumNutritionGlass(
            compact: true,
            showLabel: false,
            child: Semantics(
              value: displayValue,
              child: LayoutBuilder(
                builder: (context, constraints) => SizedBox.square(
                  dimension: constraints.maxWidth.clamp(62.0, 82.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: ExcludeSemantics(
                          excluding: grams == null || !hasGoal,
                          child: BilStripedProgress(
                            nutritionColors: true,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              color: color,
                              backgroundColor: color.withValues(alpha: .13),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(9),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            displayValue,
                            maxLines: 1,
                            textDirection: TextDirection.ltr,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealGoalSummary extends StatelessWidget {
  const _MealGoalSummary({this.goal, this.calorieOnly, this.onEdit});
  final NutritionGoalTarget? goal;
  final double? calorieOnly;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final calories = goal?.calories ?? calorieOnly;
    String grams(double? amount) => amount == null
        ? '—'
        : '${amount.toStringAsFixed(1).replaceFirst(RegExp(r"\.0$"), "")} ${_summaryText(context, 'g')}';
    final theme = Theme.of(context);
    return Column(
      key: const Key('daily-meal-detail-goal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _summaryText(context, 'mealGoal'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    key: const Key('daily-meal-edit-goal'),
                    tooltip:
                        '${context.strings.text('Edit')} · ${_summaryText(context, 'mealGoal')}',
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      padding: EdgeInsets.zero,
                      foregroundColor: theme.colorScheme.onSurface,
                      shape: const CircleBorder(),
                    ),
                    icon: BilNavigationFeedback(
                      always: true,
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.surfaceContainerLowest,
                              theme.colorScheme.surfaceContainerHigh,
                            ],
                          ),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: .8,
                          ),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: Text(
                calories == null
                    ? '— ${_summaryText(context, 'kcal')}'
                    : '${formatDiaryMacroGrams(calories)} ${_summaryText(context, 'kcal')}',
                textAlign: TextAlign.end,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in [
              ('carbs', _summaryText(context, 'carbs'), goal?.carbsGrams),
              ('fat', _summaryText(context, 'fat'), goal?.fatGrams),
              (
                'protein',
                _summaryText(context, 'proteinShort'),
                goal?.proteinGrams,
              ),
            ])
              Expanded(
                key: Key('daily-meal-goal-${item.$1}'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.$2,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (item.$3 == null)
                      const Text('—')
                    else
                      PremiumNutritionGlass(
                        compact: true,
                        showLabel: false,
                        child: Text(
                          grams(item.$3),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
