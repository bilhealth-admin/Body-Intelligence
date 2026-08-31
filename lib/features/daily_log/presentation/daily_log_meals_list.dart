import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
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
    if (mealNames.isLoading) return const LinearProgressIndicator();
    if (mealNames.hasError) {
      return ActionableErrorState(
        title: context.strings.text('Meal names could not be loaded.'),
        onRetry: () => ref.invalidate(diaryMealNamesProvider),
      );
    }
    return meals.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => ActionableErrorState(
        title: context.strings.text('Meals unavailable'),
        onRetry: () => ref.invalidate(dailyMealsProvider),
      ),
      data: (rows) {
        final configuredNames = mealNames.value;
        const indexes = {'breakfast': 0, 'lunch': 1, 'dinner': 2, 'snack': 3};
        final byType = <String, MealWithItems>{
          for (final meal in rows) meal.meal.type: meal,
        };
        final slots = <({String type, MealWithItems? meal})>[
          for (final entry in indexes.entries)
            if (() {
              final meal = byType[entry.key];
              final configuredName = configuredNames?[entry.value];
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
              _CompactDiaryMealCard(
                key: Key('daily-meal-card-${slot.type}'),
                type: slot.type,
                title: _resolvedMealName(context, mealNames, slot.type),
                meal: slot.meal,
                calorieGoal: mealCalorieGoals[slot.type],
                onAdd: () => onAdd(slot.type),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
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
        resolved[resolvedIndex]?.isNotEmpty == true) {
      return resolved[resolvedIndex]!;
    }
    return context.strings.text('${type[0].toUpperCase()}${type.substring(1)}');
  }
}

class _CompactDiaryMealCard extends StatelessWidget {
  const _CompactDiaryMealCard({
    super.key,
    required this.type,
    required this.title,
    required this.meal,
    required this.calorieGoal,
    required this.onAdd,
  });

  final String type;
  final String title;
  final MealWithItems? meal;
  final double? calorieGoal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = meal?.items ?? const <MealItem>[];
    final calories = items.fold<double>(0, (sum, item) => sum + item.calories);
    final icon = switch (type) {
      'breakfast' => Icons.wb_sunny_outlined,
      'lunch' => Icons.restaurant_outlined,
      'dinner' => Icons.nights_stay_outlined,
      _ => Icons.cookie_outlined,
    };
    final calorieText = items.isEmpty
        ? null
        : calorieGoal == null
        ? '${calories.round()} ${_mealListText(context, 'kcal')}'
        : '${calories.round()} / ${calorieGoal!.round()} ${_mealListText(context, 'kcal')}';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdd,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 94),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
            child: Row(
              key: Key('daily-meal-header-$type'),
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: .58),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        key: Key('daily-meal-title-$type'),
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      if (calorieText != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          key: Key('daily-meal-totals-$type'),
                          calorieText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: FilledButton.tonalIcon(
                    key: Key('daily-meal-log-$type'),
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        0,
                        6,
                        0,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.chevron_right_rounded, size: 19),
                    label: Text(
                      _mealListText(
                        context,
                        items.isEmpty ? 'logFood' : 'logMore',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Retained for compatibility with historical golden helpers while the live
// Today surface uses [_CompactDiaryMealCard].
// ignore: unused_element
class _DiaryMealCard extends StatelessWidget {
  const _DiaryMealCard({
    required this.type,
    required this.title,
    required this.meal,
    required this.showFoodInsights,
    required this.showFoodTimestamps,
    required this.useNetCarbs,
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
    final totals = _macroSummary(items);
    final calories = items.fold<double>(0, (sum, item) => sum + item.calories);
    final netCarbs = useNetCarbs ? knownNetCarbohydrateTotal(items) : null;
    final carbValue = useNetCarbs ? netCarbs : totals.carbs;
    final macroLine =
        'C ${carbValue == null ? '—' : formatDiaryMacroGrams(carbValue)}g   '
        'F ${formatDiaryMacroGrams(totals.fat)}g   '
        'P ${formatDiaryMacroGrams(totals.protein)}g';
    Widget logButton() => SizedBox(
      width: 124,
      child: FilledButton.tonal(
        key: Key('daily-meal-log-$type'),
        onPressed: onAdd,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: Text(
          _mealListText(context, items.isEmpty ? 'logFood' : 'logMore'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: items.isEmpty
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 100),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
                child: Row(
                  key: Key('daily-meal-header-$type'),
                  children: [
                    Expanded(
                      child: Text(
                        key: Key('daily-meal-title-$type'),
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    logButton(),
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
                                  style: Theme.of(context).textTheme.bodyMedium
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
                  for (final item in items)
                    _DiaryFoodRow(
                      item: item,
                      food: meal?.foodsById[item.foodId],
                      onEdit: onEdit,
                      onActions: onActions,
                    ),
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
