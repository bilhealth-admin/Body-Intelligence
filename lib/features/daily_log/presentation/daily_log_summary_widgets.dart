import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/localization/runtime_copy.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../commerce/presentation/premium_nutrition_glass.dart';
import '../../settings/premium_meal_features_page.dart';
import 'macro_value_formatter.dart';

part 'daily_log_summary_locale_copy.dart';
part 'daily_log_summary_metrics.dart';
part 'daily_log_meal_summary.dart';

class DiaryDateNavigator extends StatelessWidget {
  const DiaryDateNavigator({
    super.key,
    required this.date,
    required this.arabic,
    this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    this.todayHeader = false,
  });

  final DateTime date;
  final bool arabic;
  final VoidCallback? onBack;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPick;
  final bool todayHeader;

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
    final dateButton = Flexible(
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: todayHeader ? (today ? 30 : 24) : 19,
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
    );
    final back = onBack != null
        ? IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          )
        : const SizedBox(width: 48);
    final previous = IconButton(
      key: const Key('daily-log-previous'),
      tooltip: _summaryText(context, 'previous'),
      onPressed: onPrevious,
      // Material chevrons mirror themselves with Directionality. Selecting an
      // RTL-specific glyph here mirrored it a second time, so the Arabic
      // previous/next controls appeared to move in the opposite direction.
      icon: const Icon(Icons.chevron_left_rounded),
    );
    final next = IconButton(
      key: const Key('daily-log-next'),
      tooltip: _summaryText(context, 'next'),
      onPressed: onNext,
      icon: const Icon(Icons.chevron_right_rounded),
    );
    return SizedBox(
      key: const Key('daily-log-date-bar'),
      height: 64,
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: Row(
          children: todayHeader
              ? [
                  dateButton,
                  const Spacer(),
                  if (onBack != null) back,
                  previous,
                  next,
                ]
              : [
                  back,
                  const Spacer(),
                  previous,
                  dateButton,
                  next,
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
    final scheme = Theme.of(context).colorScheme;
    final hasGoal =
        calorieGoal != null && calorieGoal!.isFinite && calorieGoal! > 0;
    final remaining = hasGoal ? calorieGoal! - calories : null;
    double macroProgress(double consumed, double? goal) {
      if (goal == null || !goal.isFinite || goal <= 0) return 0.0;
      return (consumed / goal).clamp(0.0, 1.0).toDouble();
    }

    Widget surface(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
    return Column(
      key: const Key('daily-log-compact-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        surface(
          _CalorieSummary(
            calories: calories,
            calorieGoal: calorieGoal,
            remaining: remaining,
            loading: loading,
          ),
        ),
        const SizedBox(height: 10),
        surface(
          PremiumNutritionGlass(
            key: const Key('daily-log-summary-macros-glass'),
            compact: true,
            borderRadius: 14,
            child: Row(
              children: [
                Expanded(
                  child: _MacroMetric(
                    color: const Color(0xFF0A8F88),
                    percent:
                        carbsGoal == null ||
                            !carbsGoal!.isFinite ||
                            carbsGoal! <= 0
                        ? null
                        : carbs / carbsGoal! * 100,
                    progress: macroProgress(carbs, carbsGoal),
                    grams: carbs,
                    goal: carbsGoal,
                    label: _summaryText(context, 'carbs'),
                    percentKey: const Key('daily-summary-carbs-percent'),
                    gramsKey: const Key('daily-summary-carbs-grams'),
                    loading: loading,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _MacroMetric(
                    color: const Color(0xFF6F1096),
                    percent:
                        fatGoal == null || !fatGoal!.isFinite || fatGoal! <= 0
                        ? null
                        : fat / fatGoal! * 100,
                    progress: macroProgress(fat, fatGoal),
                    grams: fat,
                    goal: fatGoal,
                    label: _summaryText(context, 'fat'),
                    percentKey: const Key('daily-summary-fat-percent'),
                    gramsKey: const Key('daily-summary-fat-grams'),
                    loading: loading,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _MacroMetric(
                    color: const Color(0xFFC56A00),
                    percent:
                        proteinGoal == null ||
                            !proteinGoal!.isFinite ||
                            proteinGoal! <= 0
                        ? null
                        : protein / proteinGoal! * 100,
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
        ),
      ],
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final values = <Widget>[
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
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${calories.round()} ${_summaryText(context, 'kcal')}',
                      ),
                      if (goal)
                        TextSpan(
                          text: ' / ${calorieGoal!.round()}',
                          style: TextStyle(
                            fontSize: 15,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  key: const Key('daily-summary-calories-value'),
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              Text.rich(
                TextSpan(
                  children: [
                    if (!loading && goal) ...[
                      TextSpan(
                        text: '${remaining!.abs().round()} ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: remaining! < 0
                              ? scheme.error
                              : scheme.onSurface,
                        ),
                      ),
                      TextSpan(
                        text: _summaryText(
                          context,
                          remaining! >= 0 ? 'remaining' : 'over',
                        ),
                      ),
                    ] else
                      TextSpan(text: loading ? '…' : status),
                  ],
                ),
                key: const Key('daily-summary-calories-status'),
                semanticsLabel: loading ? '…' : status,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: goal && remaining! < 0
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ];
            if (constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  values.first,
                  const SizedBox(height: 4),
                  values.last,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: values.first),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: values.last,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
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
