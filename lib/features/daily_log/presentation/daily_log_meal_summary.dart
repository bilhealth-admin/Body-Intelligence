part of 'daily_log_summary_widgets.dart';

class DailyMealDetailSummary extends StatelessWidget {
  const DailyMealDetailSummary({
    super.key,
    required this.meal,
    this.calorieGoal,
    this.carbsGoal,
    this.proteinGoal,
    this.fatGoal,
    this.macroDisplay,
  });

  final MealWithItems? meal;
  final double? calorieGoal;
  final double? carbsGoal;
  final double? proteinGoal;
  final double? fatGoal;
  final MealMacroDisplay? macroDisplay;

  @override
  Widget build(BuildContext context) {
    final items = meal?.items ?? const <MealItem>[];
    final calories = items.fold<double>(
      0,
      (total, item) => total + item.calories,
    );
    final protein = items.fold<double>(
      0,
      (total, item) => total + item.protein,
    );
    final carbs = items.fold<double>(0, (total, item) => total + item.carbs);
    final fat = items.fold<double>(0, (total, item) => total + item.fats);
    double targetProgress(double consumed, double? goal) =>
        goal == null || !goal.isFinite || goal <= 0
        ? 0
        : (consumed / goal).clamp(0.0, 1.0).toDouble();
    final sodium = knownNutrientTotal(
      items,
      TrackedNutrient.sodium,
      (item) => item.sodium,
    );
    final potassium = knownNutrientTotal(
      items,
      TrackedNutrient.potassium,
      (item) => item.potassium,
    );
    final magnesium = knownNutrientTotal(
      items,
      TrackedNutrient.magnesium,
      (item) => item.magnesium,
    );
    final scheme = Theme.of(context).colorScheme;
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
            calorieGoal: calorieGoal,
            carbs: carbs,
            fat: fat,
            protein: protein,
            dimension: 116,
          );
          final macroDials = Row(
            key: const Key('daily-meal-detail-macros'),
            children: [
              Expanded(
                child: _MealMacroDial(
                  label: _summaryText(context, 'carbs'),
                  grams: carbs,
                  goalGrams: carbsGoal,
                  progress: targetProgress(carbs, carbsGoal),
                  displayPercent:
                      macroDisplay?.mode == MealMacroDisplayMode.percent,
                  color: const Color(0xFF0A8F88),
                ),
              ),
              Expanded(
                child: _MealMacroDial(
                  label: _summaryText(context, 'fat'),
                  grams: fat,
                  goalGrams: fatGoal,
                  progress: targetProgress(fat, fatGoal),
                  displayPercent:
                      macroDisplay?.mode == MealMacroDisplayMode.percent,
                  color: const Color(0xFF6F1096),
                ),
              ),
              Expanded(
                child: _MealMacroDial(
                  label: _summaryText(context, 'proteinShort'),
                  grams: protein,
                  goalGrams: proteinGoal,
                  progress: targetProgress(protein, proteinGoal),
                  displayPercent:
                      macroDisplay?.mode == MealMacroDisplayMode.percent,
                  color: const Color(0xFFC56A00),
                ),
              ),
            ],
          );
          final minerals = Wrap(
            key: const Key('daily-meal-detail-minerals'),
            alignment: WrapAlignment.center,
            spacing: 7,
            runSpacing: 7,
            children: [
              NutrientMetric(
                label: context.strings.text('Sodium'),
                value: sodium,
                unit: 'mg',
              ),
              NutrientMetric(
                label: context.strings.text('Potassium'),
                value: potassium,
                unit: 'mg',
              ),
              NutrientMetric(
                label: context.strings.text('Magnesium'),
                value: magnesium,
                unit: 'mg',
              ),
            ],
          );
          final premiumNutrition = PremiumNutritionGlass(
            key: const Key('daily-meal-detail-premium-group'),
            compact: true,
            borderRadius: 18,
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
            ],
          );
        },
      ),
    );
  }
}

class _MealMacroDial extends StatelessWidget {
  const _MealMacroDial({
    required this.label,
    required this.grams,
    required this.goalGrams,
    required this.progress,
    required this.color,
    required this.displayPercent,
  });

  final String label;
  final double grams;
  final double? goalGrams;
  final double progress;
  final Color color;
  final bool displayPercent;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goalGrams != null && goalGrams!.isFinite && goalGrams! > 0;
    final displayValue = displayPercent
        ? hasGoal
              ? '${(grams / goalGrams! * 100).round()}%'
              : '—'
        : '${formatDiaryMacroGrams(grams)} g';
    return Semantics(
      value: displayPercent
          ? displayValue
          : hasGoal
          ? '${formatDiaryMacroGrams(grams)} / ${formatDiaryMacroGrams(goalGrams!)} g'
          : '${formatDiaryMacroGrams(grams)} g',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    color: color,
                    backgroundColor: color.withValues(alpha: .13),
                    strokeCap: StrokeCap.round,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(9),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        displayValue,
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
