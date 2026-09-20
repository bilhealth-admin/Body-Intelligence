import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../commerce/presentation/premium_nutrition_glass.dart';
import 'macro_value_formatter.dart';

part 'daily_log_summary_locale_copy.dart';

class DiaryDateNavigator extends StatelessWidget {
  const DiaryDateNavigator({
    super.key,
    required this.date,
    required this.arabic,
    this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime date;
  final bool arabic;
  final VoidCallback? onBack;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final semanticLabel = today
        ? _summaryText(context, 'today')
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final visualLabel = today
        ? semanticLabel
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${(date.year % 100).toString().padLeft(2, '0')}';
    final scheme = Theme.of(context).colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      key: const Key('daily-log-date-bar'),
      height: 64,
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else
              const SizedBox(width: 48),
            const Spacer(),
            IconButton(
              key: const Key('daily-log-previous'),
              tooltip: _summaryText(context, 'previous'),
              onPressed: onPrevious,
              icon: Icon(
                rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              ),
            ),
            Flexible(
              flex: 3,
              child: TextButton(
                onPressed: onPick,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  minimumSize: const Size(92, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Directionality(
                        textDirection: today
                            ? Directionality.of(context)
                            : TextDirection.ltr,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            visualLabel,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.25,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, size: 24),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const Key('daily-log-next'),
              tooltip: _summaryText(context, 'next'),
              onPressed: onNext,
              icon: Icon(
                rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class DailyLogSnapshot extends StatelessWidget {
  const DailyLogSnapshot({
    super.key,
    required this.arabic,
    required this.meals,
    required this.water,
    this.calorieGoal,
    this.carbsGoal,
    this.proteinGoal,
    this.fatGoal,
    this.loading = false,
  });

  final bool arabic;
  final List<MealWithItems> meals;
  final List<WaterEntry> water;
  final double? calorieGoal;
  final double? carbsGoal;
  final double? proteinGoal;
  final double? fatGoal;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final items = meals.expand((entry) => entry.items).toList(growable: false);
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
    final macroEnergy = protein * 4 + carbs * 4 + fat * 9;
    final carbsPercent = macroEnergy == 0 ? 0.0 : carbs * 400 / macroEnergy;
    final fatPercent = macroEnergy == 0 ? 0.0 : fat * 900 / macroEnergy;
    final proteinPercent = macroEnergy == 0 ? 0.0 : protein * 400 / macroEnergy;
    final scheme = Theme.of(context).colorScheme;
    final hasGoal =
        calorieGoal != null && calorieGoal!.isFinite && calorieGoal! > 0;
    final remaining = hasGoal ? calorieGoal! - calories : null;
    double macroProgress(double consumed, double? goal) {
      if (goal == null || !goal.isFinite || goal <= 0) return 0.0;
      return (consumed / goal).clamp(0.0, 1.0).toDouble();
    }

    return Container(
      key: const Key('daily-log-compact-summary'),
      constraints: const BoxConstraints(minHeight: 154),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _CalorieSummary(
                  calories: calories,
                  calorieGoal: calorieGoal,
                  remaining: remaining,
                  loading: loading,
                ),
              ),
              const SizedBox(width: 10),
              Transform.translate(
                key: const Key('daily-log-summary-ring-raised'),
                offset: const Offset(0, -3),
                child: loading
                    ? _SummaryRingSkeleton(
                        color: scheme.surfaceContainerHighest,
                      )
                    : DailyLogCalorieMacroRing(
                        calories: calories,
                        calorieGoal: calorieGoal,
                        carbs: carbs,
                        fat: fat,
                        protein: protein,
                        dimension: 84,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PremiumNutritionGlass(
            key: const Key('daily-log-summary-macros-glass'),
            compact: true,
            borderRadius: 14,
            child: Row(
              children: [
                Expanded(
                  child: _MacroMetric(
                    color: const Color(0xFF0A8F88),
                    percent: carbsGoal == null || carbsGoal! <= 0
                        ? carbsPercent
                        : (carbs / carbsGoal! * 100).clamp(0, 100),
                    progress: macroProgress(carbs, carbsGoal),
                    grams: carbs,
                    goal: carbsGoal,
                    label: _summaryText(context, 'carbs'),
                    percentKey: const Key('daily-summary-carbs-percent'),
                    gramsKey: const Key('daily-summary-carbs-grams'),
                    loading: loading,
                  ),
                ),
                Expanded(
                  child: _MacroMetric(
                    color: const Color(0xFF6F1096),
                    percent: fatGoal == null || fatGoal! <= 0
                        ? fatPercent
                        : (fat / fatGoal! * 100).clamp(0, 100),
                    progress: macroProgress(fat, fatGoal),
                    grams: fat,
                    goal: fatGoal,
                    label: _summaryText(context, 'fat'),
                    percentKey: const Key('daily-summary-fat-percent'),
                    gramsKey: const Key('daily-summary-fat-grams'),
                    loading: loading,
                  ),
                ),
                Expanded(
                  child: _MacroMetric(
                    color: const Color(0xFFC56A00),
                    percent: proteinGoal == null || proteinGoal! <= 0
                        ? proteinPercent
                        : (protein / proteinGoal! * 100).clamp(0, 100),
                    progress: macroProgress(protein, proteinGoal),
                    grams: protein,
                    goal: proteinGoal,
                    label: _summaryText(context, 'proteinShort'),
                    percentKey: const Key('daily-summary-protein-percent'),
                    gramsKey: const Key('daily-summary-protein-grams'),
                    loading: loading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieSummary extends StatelessWidget {
  const _CalorieSummary({
    required this.calories,
    required this.calorieGoal,
    required this.remaining,
    required this.loading,
  });

  final double calories;
  final double? calorieGoal;
  final double? remaining;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final goal =
        calorieGoal != null && calorieGoal!.isFinite && calorieGoal! > 0;
    final status = !goal
        ? _summaryText(context, 'noGoal')
        : remaining! >= 0
        ? '${remaining!.round()} ${_summaryText(context, 'kcal')} ${_summaryText(context, 'remaining')}'
        : '${(-remaining!).round()} ${_summaryText(context, 'kcal')} ${_summaryText(context, 'over')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _summaryText(context, 'calories'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        if (loading)
          Container(
            key: const Key('daily-summary-calories-loading'),
            width: 150,
            height: 27,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          )
        else
          Text(
            '${calories.round()} ${_summaryText(context, 'kcal')}${goal ? ' / ${calorieGoal!.round()}' : ''}',
            key: const Key('daily-summary-calories-value'),
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          loading ? '…' : status,
          key: const Key('daily-summary-calories-status'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: goal && remaining! < 0
                ? scheme.error
                : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            key: const Key('daily-summary-calories-progress'),
            minHeight: 7,
            value: loading || !goal
                ? 0
                : (calories / calorieGoal!).clamp(0.0, 1.0).toDouble(),
            backgroundColor: scheme.surfaceContainerHighest,
            color: goal && remaining! < 0 ? scheme.error : scheme.primary,
          ),
        ),
      ],
    );
  }
}

class _SummaryRingSkeleton extends StatelessWidget {
  const _SummaryRingSkeleton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 84,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 10),
        ),
      ),
    );
  }
}

class DailyMealDetailSummary extends StatelessWidget {
  const DailyMealDetailSummary({
    super.key,
    required this.meal,
    this.calorieGoal,
  });

  final MealWithItems? meal;
  final double? calorieGoal;

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
    final macroEnergy = protein * 4 + carbs * 4 + fat * 9;
    double ratio(double energy) => macroEnergy <= 0
        ? 0
        : (energy / macroEnergy).clamp(0.0, 1.0).toDouble();
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
                  progress: ratio(carbs * 4),
                  color: const Color(0xFF0A8F88),
                ),
              ),
              Expanded(
                child: _MealMacroDial(
                  label: _summaryText(context, 'fat'),
                  grams: fat,
                  progress: ratio(fat * 9),
                  color: const Color(0xFF6F1096),
                ),
              ),
              Expanded(
                child: _MealMacroDial(
                  label: _summaryText(context, 'proteinShort'),
                  grams: protein,
                  progress: ratio(protein * 4),
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
                children: [macroDials, const SizedBox(height: 14), minerals],
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
    required this.progress,
    required this.color,
  });

  final String label;
  final double grams;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                      '${formatDiaryMacroGrams(grams)} g',
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
    );
  }
}

class DailyLogCalorieMacroRing extends StatelessWidget {
  const DailyLogCalorieMacroRing({
    super.key,
    required this.calories,
    required this.calorieGoal,
    required this.carbs,
    required this.fat,
    required this.protein,
    this.dimension = 126,
  });

  final double calories;
  final double? calorieGoal;
  final double carbs;
  final double fat;
  final double protein;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${calories.round()} ${_summaryText(context, 'kcal')}${calorieGoal == null ? '' : ' / ${calorieGoal!.round()}'}',
      child: SizedBox.square(
        dimension: dimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(dimension),
              painter: _MacroRingPainter(
                carbs: carbs,
                fat: fat,
                protein: protein,
                track: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(dimension * 0.17),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      calories.round().toString(),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                    ),
                    Text(
                      _summaryText(context, 'kcal'),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (calorieGoal != null)
                      Text(
                        '/ ${calorieGoal!.round()}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRingPainter extends CustomPainter {
  const _MacroRingPainter({
    required this.carbs,
    required this.fat,
    required this.protein,
    required this.track,
  });

  final double carbs;
  final double fat;
  final double protein;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Color(0xFF0A8F88), Color(0xFF6F1096), Color(0xFFFFAB32)];
    final energies = [carbs * 4, fat * 9, protein * 4];
    final total = energies.fold<double>(0, (sum, value) => sum + value);
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 12) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, paint..color = track);
    if (total <= 0) return;
    var start = -1.5707963267948966;
    for (var i = 0; i < energies.length; i++) {
      final sweep = 6.283185307179586 * energies[i] / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) =>
      carbs != oldDelegate.carbs ||
      fat != oldDelegate.fat ||
      protein != oldDelegate.protein ||
      track != oldDelegate.track;
}

class _MacroMetric extends StatelessWidget {
  const _MacroMetric({
    required this.color,
    required this.percent,
    required this.progress,
    required this.grams,
    required this.goal,
    required this.label,
    this.percentKey,
    this.gramsKey,
    this.loading = false,
  });

  final Color color;
  final double percent;
  final double progress;
  final double grams;
  final double? goal;
  final String label;
  final Key? percentKey;
  final Key? gramsKey;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${percent.round()}%',
          key: percentKey,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${formatDiaryMacroGrams(grams)} g',
            key: gramsKey,
            maxLines: 1,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 4,
            value: loading ? 0 : progress,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          goal == null || goal! <= 0
              ? label
              : '$label / ${formatDiaryMacroGrams(goal!)} g',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class NutrientMetric extends StatelessWidget {
  const NutrientMetric({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final localizedUnit = _summaryText(context, unit);
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.science_outlined,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value == null
                    ? '$label: ${context.strings.text('Unavailable')}'
                    : '$label ${value!.toStringAsFixed(1)} $localizedUnit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
