import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';

import '../../data/repositories/meal_repository.dart';
import '../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../data/database/app_database.dart';
import '../../data/database/nutrient_evidence.dart';
import '../../engine/body_profile.dart';
import '../../engine/daily_targets.dart';
import '../../engine/plan_engine.dart';
import '../../shared/widgets/secondary_page_app_bar.dart';
import '../daily_log/providers/daily_log_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';
import '../dashboard/domain/nutrient_dashboard.dart';
import '../dashboard/providers/dashboard_preferences_provider.dart';
import '../nutrition/domain/percentage_nutrition_goals.dart';
import 'domain/food_analysis_engine.dart';

part 'nutrition_analytics_food.dart';
part 'nutrition_analytics_totals.dart';
part 'nutrition_analytics_calories.dart';
part 'nutrition_analytics_nutrients.dart';
part 'nutrition_analytics_macros.dart';
part 'nutrition_analytics_components.dart';

class NutritionAnalyticsPage extends ConsumerWidget {
  const NutritionAnalyticsPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(dailyMealsProvider);
    final profileState = ref.watch(userProfileProvider);
    final effectiveCurrentWeight = ref.watch(effectiveCurrentWeightProvider);
    final latestBodyMeasurement = ref
        .watch(bodyMeasurementHistoryProvider)
        .value
        ?.firstOrNull;
    final goalState = ref.watch(activeGoalProvider);
    if (profileState.isLoading || goalState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profileState.hasError || goalState.hasError) {
      return _NutritionDependencyError(
        onRetry: () {
          ref.invalidate(userProfileProvider);
          ref.invalidate(activeGoalProvider);
        },
      );
    }
    final profile = profileState.value;
    final goal = goalState.value;
    final presetState = ref.watch(dashboardNutrientDashboardProvider);
    const goalKeys = <String>[
      'goal.calories',
      'goal.carbsPercent',
      'goal.proteinPercent',
      'goal.fatPercent',
      'goal.saturatedFat',
      'goal.sodium',
      'goal.fiber',
      'goal.sugar',
    ];
    final goalStates = {
      for (final key in goalKeys)
        key: ref.watch(dashboardNutrientGoalProvider(key)),
    };
    if (presetState.isLoading ||
        goalStates.values.any((state) => state.isLoading)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (presetState.hasError ||
        goalStates.values.any((state) => state.hasError)) {
      return _NutritionDependencyError(
        onRetry: () {
          ref.invalidate(dashboardNutrientDashboardProvider);
          for (final key in goalKeys) {
            ref.invalidate(dashboardNutrientGoalProvider(key));
          }
        },
      );
    }
    double? storedGoal(String key) => goalStates[key]?.value;
    final nutrientPreset = NutrientDashboardPreset.parse(presetState.value);
    final caloriesGoal = storedGoal('goal.calories');
    final carbsPercent = storedGoal('goal.carbsPercent');
    final proteinPercent = storedGoal('goal.proteinPercent');
    final fatPercent = storedGoal('goal.fatPercent');
    final percentageGoals =
        caloriesGoal == null ||
            carbsPercent == null ||
            proteinPercent == null ||
            fatPercent == null
        ? null
        : PercentageNutritionGoals.resolve(
            calories: caloriesGoal,
            carbohydratesPercent: carbsPercent,
            proteinPercent: proteinPercent,
            fatPercent: fatPercent,
          );
    final saturatedFatGoal = storedGoal('goal.saturatedFat');
    final sodiumGoal = storedGoal('goal.sodium');
    final fiberGoal = storedGoal('goal.fiber');
    final sugarGoal = storedGoal('goal.sugar');
    final planState = profile == null
        ? const AsyncValue<PlanSetting?>.data(null)
        : ref.watch(planSettingProvider(profile.uuid));
    if (planState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (planState.hasError) {
      return _NutritionDependencyError(
        onRetry: () => ref.invalidate(planSettingProvider(profile!.uuid)),
      );
    }
    final plan = planState.value;
    final planTargets = profile == null
        ? const _NutritionTargets()
        : _NutritionTargets.from(
            PlanEngine.recommend(
              BodyProfile(
                age: profile.age,
                gender: profile.gender,
                height: profile.height,
                weight: effectiveCurrentWeight ?? profile.currentWeight,
                targetWeight: profile.targetWeight,
                activityLevel: profile.activityLevel,
                exercises: profile.exercises,
                goalType: goal?.type ?? 'maintain',
                waistCm: latestBodyMeasurement?.waistCm ?? profile.waist,
                neckCm: latestBodyMeasurement?.neckCm ?? profile.neck,
                hipCm: latestBodyMeasurement?.hipsCm,
              ),
            ).targets,
            calories: plan?.overrideCalories,
            protein: plan?.overrideProtein,
            carbs: plan?.overrideCarbs,
            fats: plan?.overrideFats,
            fiber: plan?.overrideFiber,
          );
    final goalSchedule =
        ref.watch(nutritionGoalScheduleProvider).value ??
        const NutritionGoalSchedule();
    final selectedDayTarget = goalSchedule.targetFor(
      ref.watch(selectedLogDateProvider),
    );
    final scheduledGoals = selectedDayTarget == null
        ? null
        : PercentageNutritionGoals.resolve(
            calories: selectedDayTarget.calories,
            carbohydratesPercent: selectedDayTarget.carbsPercent,
            proteinPercent: selectedDayTarget.proteinPercent,
            fatPercent: selectedDayTarget.fatPercent,
          );
    final effectivePercentageGoals = scheduledGoals ?? percentageGoals;
    final targets = effectivePercentageGoals == null
        ? planTargets
        : _NutritionTargets(
            calories: effectivePercentageGoals.calories,
            protein: effectivePercentageGoals.proteinGrams,
            carbs: effectivePercentageGoals.carbohydratesGrams,
            fats: effectivePercentageGoals.fatGrams,
            fiber: planTargets.fiber,
          );
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab.clamp(0, 3),
      child: Scaffold(
        appBar: SecondaryPageAppBar(
          title: Text(_t(context, 'Nutrition')),
          actions: [
            IconButton(
              tooltip: _t(context, 'Export'),
              onPressed: () {
                final day = DateUtils.dateOnly(
                  ref.read(selectedLogDateProvider),
                );
                final iso = day.toIso8601String().split('T').first;
                context.push('/settings/local-export?from=$iso&to=$iso');
              },
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerHeight: 1,
              tabs: [
                Tab(text: _t(context, 'Calories')),
                Tab(text: _t(context, 'Nutrients')),
                Tab(text: _t(context, 'Macros')),
                Tab(text: _t(context, 'Food analysis')),
              ],
            ),
            Expanded(
              child: meals.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: FilledButton(
                    onPressed: () => ref.invalidate(dailyMealsProvider),
                    child: Text(_t(context, 'Try again')),
                  ),
                ),
                data: (value) {
                  final totals = NutritionAnalyticsTotals.fromMeals(value);
                  final evidence = _dashboardEvidence(value);
                  if (value.every((meal) => meal.items.isEmpty)) {
                    return _NutritionEmptyDay(
                      onLogFood: () => context.push('/nutrition'),
                    );
                  }
                  return TabBarView(
                    children: [
                      _CaloriesTab(
                        meals: value,
                        totals: totals,
                        goal: targets.calories,
                      ),
                      _NutrientsTab(
                        totals: totals,
                        targets: targets,
                        preset: nutrientPreset,
                        evidence: evidence,
                        goals: NutrientDashboardGoalSet(
                          saturatedFatG: saturatedFatGoal,
                          sodiumMg: sodiumGoal,
                          fiberG: fiberGoal,
                          carbohydratesG: targets.carbs,
                          sugarG: sugarGoal,
                        ),
                      ),
                      _MacrosTab(totals: totals, targets: targets),
                      _FoodAnalysisTab(meals: value),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionEmptyDay extends StatelessWidget {
  const _NutritionEmptyDay({required this.onLogFood});

  final VoidCallback onLogFood;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const _DayHeader(),
      const SizedBox(height: 56),
      Icon(
        Icons.restaurant_menu_rounded,
        size: 56,
        color: Theme.of(context).colorScheme.outline,
      ),
      const SizedBox(height: 16),
      Text(
        _t(context, 'No foods logged for this day.'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        _t(context, 'Log food to see evidence-backed nutrition totals.'),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: onLogFood,
        icon: const Icon(Icons.add_rounded),
        label: Text(_t(context, 'Log food')),
      ),
    ],
  );
}

class _NutritionDependencyError extends StatelessWidget {
  const _NutritionDependencyError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SecondaryPageAppBar(title: Text(_t(context, 'Nutrition'))),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_problem_rounded, size: 44),
            const SizedBox(height: 12),
            Text(
              _t(context, 'Nutrition goals could not be loaded.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_t(context, 'Try again')),
            ),
          ],
        ),
      ),
    ),
  );
}

Map<TrackedNutrient, EvidencedNutrientValue> _dashboardEvidence(
  List<MealWithItems> meals,
) {
  final samples = [
    for (final item in meals.expand((meal) => meal.items))
      NutrientDashboardSample(
        evidenceMask: item.nutrientEvidenceMask,
        values: {
          TrackedNutrient.sodium: item.sodium,
          TrackedNutrient.fiber: item.fiber,
          TrackedNutrient.carbohydrates: item.carbs,
          TrackedNutrient.sugar: item.sugar,
        },
      ),
  ];
  return {
    for (final nutrient in const [
      TrackedNutrient.sodium,
      TrackedNutrient.fiber,
      TrackedNutrient.carbohydrates,
      TrackedNutrient.sugar,
    ])
      nutrient: NutrientDashboardEvidence.total(samples, nutrient),
  };
}
