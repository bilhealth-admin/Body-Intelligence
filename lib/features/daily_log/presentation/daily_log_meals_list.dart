import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import '../../../app/theme/bil_semantic_icons.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../../shared/widgets/actionable_error_state.dart';
import '../../settings/premium_meal_features_page.dart';
import '../../nutrition/services/food_presentation_localizer.dart';
import '../../commerce/presentation/premium_nutrition_glass.dart';
import '../providers/daily_log_provider.dart';
import 'macro_value_formatter.dart';

part 'daily_log_meal_detail_items.dart';

class DailyMealsList extends ConsumerWidget {
  const DailyMealsList({
    super.key,
    required this.arabic,
    required this.meals,
    this.showEmptyMealSlots = true,
    this.showFoodInsights = true,
    this.showFoodTimestamps = false,
    this.useNetCarbs = false,
    this.dailyGoal,
    this.mealGoals = const {},
    this.mealCalorieGoals = const {},
    this.mealMacroDisplay,
    required this.onAdd,
    required this.onEdit,
    required this.onActions,
  });

  final bool arabic;
  final AsyncValue<List<MealWithItems>> meals;
  final bool showEmptyMealSlots;
  final bool showFoodInsights;
  final bool showFoodTimestamps;
  final bool useNetCarbs;
  final NutritionGoalTarget? dailyGoal;
  final Map<String, NutritionGoalTarget> mealGoals;
  final Map<String, double> mealCalorieGoals;
  final MealMacroDisplay? mealMacroDisplay;
  final ValueChanged<String> onAdd;
  final Future<void> Function(MealItem item, Food food) onEdit;
  final Future<void> Function(MealItem item, Food? food) onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealNames = ref.watch(diaryMealNamesProvider);
    // A date switch invalidates this stream. Keep the meal slots in place
    // while the new day arrives instead of replacing the Today surface with
    // a page-level progress indicator. The skeleton deliberately contains no
    // previous-day values, so the new date cannot display stale meals.
    if (meals.isLoading || mealNames.isLoading) {
      return const _DiaryMealsSkeleton();
    }
    if (meals.hasError) {
      return ActionableErrorState(
        title: context.strings.text('Meals unavailable'),
        onRetry: () => ref.invalidate(dailyMealsProvider),
      );
    }
    if (mealNames.hasError) {
      return ActionableErrorState(
        title: context.strings.text('Meal names could not be loaded.'),
        onRetry: () => ref.invalidate(diaryMealNamesProvider),
      );
    }
    final rows = meals.value ?? const <MealWithItems>[];
    final configuredNames = mealNames.value;
    const indexes = {'breakfast': 0, 'lunch': 1, 'dinner': 2, 'snack': 3};
    final byType = <String, MealWithItems>{
      for (final meal in rows) meal.meal.type: meal,
    };
    final slots = <({String type, MealWithItems? meal})>[
      for (final entry in indexes.entries)
        if (() {
          final meal = byType[entry.key];
          final configuredName =
              configuredNames != null && entry.value < configuredNames.length
              ? configuredNames[entry.value]
              : null;
          final enabled =
              configuredNames == null ||
              configuredName == null ||
              configuredName.isNotEmpty;
          return (meal?.items.isNotEmpty ?? false) ||
              (showEmptyMealSlots && enabled);
        }())
          (type: entry.key, meal: byType[entry.key]),
      for (final meal in rows)
        if (!indexes.containsKey(meal.meal.type))
          (type: meal.meal.type, meal: meal),
    ];
    if (slots.isEmpty) {
      return _DiaryEmptyMeals(onAdd: () => onAdd('breakfast'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in slots) ...[
          _DiaryMealCard(
            key: Key('daily-meal-card-${slot.type}'),
            type: slot.type,
            title: _resolvedMealName(context, mealNames, slot.type),
            meal: slot.meal,
            showFoodInsights: showFoodInsights,
            showFoodTimestamps: showFoodTimestamps,
            useNetCarbs: useNetCarbs,
            dailyGoal: dailyGoal,
            mealGoal: mealGoals[slot.type],
            calorieGoal:
                mealGoals[slot.type]?.calories ?? mealCalorieGoals[slot.type],
            macroDisplay: mealMacroDisplay,
            onAdd: () => onAdd(slot.type),
            onEdit: onEdit,
            onActions: onActions,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _resolvedMealName(
    BuildContext context,
    AsyncValue<List<String?>> names,
    String type,
  ) {
    const index = {'breakfast': 0, 'lunch': 1, 'dinner': 2, 'snack': 3};
    final resolvedIndex = index[type];
    final resolved = names.value;
    if (resolvedIndex != null &&
        resolved != null &&
        resolvedIndex < resolved.length &&
        resolved[resolvedIndex]?.isNotEmpty == true) {
      return resolved[resolvedIndex]!;
    }
    return context.strings.text('${type[0].toUpperCase()}${type.substring(1)}');
  }
}

class _DiaryMealsSkeleton extends StatelessWidget {
  const _DiaryMealsSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const Key('daily-meal-loading-skeleton'),
      children: [
        for (var index = 0; index < 4; index++) ...[
          Container(
            height: 68,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 108,
                  height: 14,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 72,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DiaryMealCard extends StatelessWidget {
  const _DiaryMealCard({
    super.key,
    required this.type,
    required this.title,
    required this.meal,
    required this.showFoodInsights,
    required this.showFoodTimestamps,
    required this.useNetCarbs,
    required this.dailyGoal,
    required this.mealGoal,
    required this.calorieGoal,
    required this.macroDisplay,
    required this.onAdd,
    required this.onEdit,
    required this.onActions,
  });

  final String type;
  final String title;
  final MealWithItems? meal;
  final bool showFoodInsights;
  final bool showFoodTimestamps;
  final bool useNetCarbs;
  final NutritionGoalTarget? dailyGoal;
  final NutritionGoalTarget? mealGoal;
  final double? calorieGoal;
  final MealMacroDisplay? macroDisplay;
  final VoidCallback onAdd;
  final Future<void> Function(MealItem item, Food food) onEdit;
  final Future<void> Function(MealItem item, Food? food) onActions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = meal?.items ?? const <MealItem>[];
    final totals = (
      carbs: items.fold<double>(0, (sum, item) => sum + item.carbs),
      protein: items.fold<double>(0, (sum, item) => sum + item.protein),
      fat: items.fold<double>(0, (sum, item) => sum + item.fats),
    );
    final calories = items.fold<double>(0, (sum, item) => sum + item.calories);
    final netCarbs = useNetCarbs ? knownNetCarbohydrateTotal(items) : null;
    final carbValue = useNetCarbs ? netCarbs : totals.carbs;
    final showMacroSummary = items.isNotEmpty && macroDisplay?.enabled == true;
    final effectiveGoal = mealGoal ?? dailyGoal;
    final macroLine = _mealMacroLine(
      display: macroDisplay,
      carbs: carbValue,
      protein: totals.protein,
      fat: totals.fat,
      goal: effectiveGoal,
    );
    final macroGoalText = mealGoal == null
        ? null
        : '${_mealListText(context, 'mealGoal')}: '
              '${mealGoal!.calories.round()} ${_mealListText(context, 'kcal')}  '
              'C ${mealGoal!.carbsGrams.round()} g  '
              'P ${mealGoal!.proteinGrams.round()} g  '
              'F ${mealGoal!.fatGrams.round()} g';
    Widget logButton() => SizedBox(
      width: 100,
      child: FilledButton.tonal(
        key: Key('daily-meal-log-$type'),
        onPressed: onAdd,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          backgroundColor: scheme.primary.withValues(alpha: .10),
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(
          _mealListText(context, 'logMore'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
    Widget plannerAction() => PopupMenuButton<String>(
      key: Key('daily-meal-planner-$type'),
      tooltip: _mealListText(context, 'logFood'),
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (_) => context.push('/meal-planner'),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'planner',
          child: Text(_mealListText(context, 'logFood')),
        ),
      ],
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: items.isEmpty
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      key: Key('daily-meal-header-$type'),
                      children: [
                        Icon(
                          BilSemanticIcons.spec(_mealSemanticIcon(type)).icon,
                          color: scheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            key: Key('daily-meal-title-$type'),
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.25,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        plannerAction(),
                        const SizedBox(width: 2),
                        logButton(),
                      ],
                    ),
                    if (macroGoalText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        key: Key('daily-meal-macro-goal-$type'),
                        macroGoalText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 15, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    key: Key('daily-meal-header-$type'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        BilSemanticIcons.spec(_mealSemanticIcon(type)).icon,
                        color: scheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              key: Key('daily-meal-title-$type'),
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.25,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            if (showMacroSummary)
                              PremiumNutritionGlass(
                                key: Key('daily-meal-macros-$type'),
                                compact: true,
                                showLabel: false,
                                borderRadius: 8,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Text(
                                    macroLine,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.ltr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontSize: 13,
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      plannerAction(),
                      const SizedBox(width: 2),
                      Text(
                        key: Key('daily-meal-totals-$type'),
                        '${calories.round()} ${_mealListText(context, 'kcal')}',
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(
                    key: Key('daily-meal-divider-$type'),
                    height: 1,
                    color: scheme.outlineVariant,
                  ),
                  const SizedBox(height: 7),
                  const SizedBox(height: 2),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: logButton(),
                  ),
                ],
              ),
            ),
    );
  }
}

BilSemanticIconKind _mealSemanticIcon(String type) => switch (type) {
  'breakfast' => BilSemanticIconKind.breakfast,
  'lunch' => BilSemanticIconKind.lunch,
  'dinner' => BilSemanticIconKind.dinner,
  _ => BilSemanticIconKind.snack,
};

String _mealMacroLine({
  required MealMacroDisplay? display,
  required double? carbs,
  required double protein,
  required double fat,
  required NutritionGoalTarget? goal,
}) {
  String grams(String label, double? consumed, double? target) {
    if (consumed == null) return '$label —';
    final consumedText = formatDiaryMacroGrams(consumed);
    if (target == null || !target.isFinite || target <= 0) {
      return '$label $consumedText g';
    }
    return '$label $consumedText / ${formatDiaryMacroGrams(target)} g';
  }

  String percent(String label, double? consumed, double? target) {
    if (consumed == null || target == null || !target.isFinite || target <= 0) {
      return '$label —';
    }
    return '$label ${(consumed / target * 100).round()}%';
  }

  if (display?.mode == MealMacroDisplayMode.percent) {
    return '${percent('C', carbs, goal?.carbsGrams)}   '
        '${percent('P', protein, goal?.proteinGrams)}   '
        '${percent('F', fat, goal?.fatGrams)}';
  }
  return '${grams('C', carbs, goal?.carbsGrams)}   '
      '${grams('P', protein, goal?.proteinGrams)}   '
      '${grams('F', fat, goal?.fatGrams)}';
}
