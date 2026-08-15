import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';

import '../../data/repositories/meal_repository.dart';
import '../../data/database/app_database.dart';
import '../../data/database/nutrient_evidence.dart';
import '../../engine/body_profile.dart';
import '../../engine/daily_targets.dart';
import '../../engine/plan_engine.dart';
import '../../shared/widgets/secondary_page_app_bar.dart';
import '../daily_log/providers/daily_log_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../dashboard/domain/nutrient_dashboard.dart';
import '../dashboard/providers/dashboard_preferences_provider.dart';
import '../nutrition/domain/percentage_nutrition_goals.dart';
import 'domain/food_analysis_engine.dart';

class NutritionAnalyticsPage extends ConsumerWidget {
  const NutritionAnalyticsPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(dailyMealsProvider);
    final profileState = ref.watch(userProfileProvider);
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
                weight: profile.currentWeight,
                targetWeight: profile.targetWeight,
                activityLevel: profile.activityLevel,
                exercises: profile.exercises,
                goalType: goal?.type ?? 'maintain',
              ),
            ).targets,
            calories: plan?.overrideCalories,
            protein: plan?.overrideProtein,
            carbs: plan?.overrideCarbs,
            fats: plan?.overrideFats,
            fiber: plan?.overrideFiber,
          );
    final targets = percentageGoals == null
        ? planTargets
        : _NutritionTargets(
            calories: percentageGoals.calories,
            protein: percentageGoals.proteinGrams,
            carbs: percentageGoals.carbohydratesGrams,
            fats: percentageGoals.fatGrams,
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

class _FoodAnalysisTab extends StatefulWidget {
  const _FoodAnalysisTab({required this.meals});

  final List<MealWithItems> meals;

  @override
  State<_FoodAnalysisTab> createState() => _FoodAnalysisTabState();
}

class _FoodAnalysisTabState extends State<_FoodAnalysisTab> {
  TrackedNutrient selected = TrackedNutrient.protein;

  static const choices = <TrackedNutrient>[
    TrackedNutrient.calories,
    TrackedNutrient.protein,
    TrackedNutrient.carbohydrates,
    TrackedNutrient.fat,
    TrackedNutrient.fiber,
    TrackedNutrient.sugar,
    TrackedNutrient.sodium,
    TrackedNutrient.potassium,
  ];

  @override
  Widget build(BuildContext context) {
    final snapshots = <FoodAnalysisItemSnapshot>[
      for (final meal in widget.meals)
        for (final item in meal.items)
          FoodAnalysisItemSnapshot(
            foodId: item.foodId,
            foodName:
                meal.foodsById[item.foodId]?.name ??
                _t(context, 'Unknown food'),
            nutrientEvidenceMask: item.nutrientEvidenceMask,
            source: item.foodSourceSnapshot,
            verified: item.foodVerifiedSnapshot,
            values: {
              TrackedNutrient.calories: item.calories,
              TrackedNutrient.protein: item.protein,
              TrackedNutrient.carbohydrates: item.carbs,
              TrackedNutrient.fat: item.fats,
              TrackedNutrient.fiber: item.fiber,
              TrackedNutrient.sugar: item.sugar,
              TrackedNutrient.sodium: item.sodium,
              TrackedNutrient.potassium: item.potassium,
              TrackedNutrient.calcium: item.calcium,
              TrackedNutrient.magnesium: item.magnesium,
              TrackedNutrient.phosphorus: item.phosphorus,
            },
          ),
    ];
    final analysis = FoodAnalysisEngine.analyze(
      items: snapshots,
      nutrient: selected,
    );
    final unit = _unitFor(selected);
    return ListView(
      key: const Key('nutrition-food-analysis-tab'),
      padding: const EdgeInsets.all(20),
      children: [
        const _DayHeader(),
        const SizedBox(height: 18),
        Text(
          _t(context, 'Choose a nutrient'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TrackedNutrient>(
          initialValue: selected,
          items: [
            for (final nutrient in choices)
              DropdownMenuItem(
                value: nutrient,
                child: Text(_t(context, _nutrientKey(nutrient))),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => selected = value);
          },
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: _t(context, 'Nutrient'),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _t(context, 'Top contributors'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          _coverageText(context, analysis),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (analysis.contributors.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(_t(context, 'No evidenced values are available.')),
            ),
          )
        else
          for (final contributor in analysis.contributors)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contributor.foodName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${contributor.value.round()} $unit · '
                          '${(contributor.share * 100).round()}%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: contributor.share),
                    const SizedBox(height: 8),
                    Text(
                      '${_t(context, 'Logged entries')}: '
                      '${contributor.entryCount} · '
                      '${contributor.allSnapshotsVerified ? _t(context, 'Verified snapshot') : _t(context, 'Unverified snapshot')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _t(
                context,
                'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.',
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _coverageText(BuildContext context, FoodNutrientAnalysis analysis) {
    if (analysis.coverage == FoodAnalysisCoverage.none) {
      return _t(context, 'No logged item has evidence for this nutrient.');
    }
    final base =
        '${_t(context, 'Known total')}: '
        '${analysis.knownTotal.round()} ${_unitFor(selected)}';
    if (analysis.unknownEntryCount == 0) return base;
    return '$base · ${_t(context, 'Entries with unknown values')}: '
        '${analysis.unknownEntryCount}';
  }
}

String _unitFor(TrackedNutrient nutrient) => switch (nutrient) {
  TrackedNutrient.calories => 'kcal',
  TrackedNutrient.sodium ||
  TrackedNutrient.potassium ||
  TrackedNutrient.calcium ||
  TrackedNutrient.magnesium ||
  TrackedNutrient.phosphorus => 'mg',
  _ => 'g',
};

String _nutrientKey(TrackedNutrient nutrient) => switch (nutrient) {
  TrackedNutrient.calories => 'Calories',
  TrackedNutrient.protein => 'Protein',
  TrackedNutrient.carbohydrates => 'Carbohydrates',
  TrackedNutrient.fat => 'Fat',
  TrackedNutrient.fiber => 'Fiber',
  TrackedNutrient.sugar => 'Sugar',
  TrackedNutrient.sodium => 'Sodium',
  TrackedNutrient.potassium => 'Potassium',
  TrackedNutrient.calcium => 'Calcium',
  TrackedNutrient.magnesium => 'Magnesium',
  TrackedNutrient.phosphorus => 'Phosphorus',
};

class NutritionAnalyticsTotals {
  const NutritionAnalyticsTotals({
    required this.values,
    required this.knownCounts,
    required this.unknownCounts,
  });
  final Map<TrackedNutrient, double> values;
  final Map<TrackedNutrient, int> knownCounts;
  final Map<TrackedNutrient, int> unknownCounts;

  double value(TrackedNutrient nutrient) => values[nutrient] ?? 0;
  bool isKnown(TrackedNutrient nutrient) => (knownCounts[nutrient] ?? 0) > 0;
  bool isComplete(TrackedNutrient nutrient) =>
      isKnown(nutrient) && (unknownCounts[nutrient] ?? 0) == 0;

  double get calories => value(TrackedNutrient.calories);
  double get protein => value(TrackedNutrient.protein);
  double get carbs => value(TrackedNutrient.carbohydrates);
  double get fats => value(TrackedNutrient.fat);
  double get fiber => value(TrackedNutrient.fiber);
  double get sugar => value(TrackedNutrient.sugar);
  double get sodium => value(TrackedNutrient.sodium);
  double get potassium => value(TrackedNutrient.potassium);
  double get calcium => value(TrackedNutrient.calcium);
  double get magnesium => value(TrackedNutrient.magnesium);
  double get phosphorus => value(TrackedNutrient.phosphorus);

  factory NutritionAnalyticsTotals.fromMeals(List<MealWithItems> meals) {
    final items = meals.expand((meal) => meal.items).toList(growable: false);
    final values = <TrackedNutrient, double>{};
    final known = <TrackedNutrient, int>{};
    final unknown = <TrackedNutrient, int>{};
    for (final nutrient in TrackedNutrient.values) {
      var total = 0.0;
      var knownCount = 0;
      var unknownCount = 0;
      for (final item in items) {
        final amount = _itemNutrientValue(item, nutrient);
        final evidenced = NutrientEvidenceMask.contains(
          item.nutrientEvidenceMask,
          nutrient,
        );
        if (!evidenced || !amount.isFinite || amount < 0) {
          unknownCount++;
          continue;
        }
        total += amount;
        knownCount++;
      }
      values[nutrient] = total;
      known[nutrient] = knownCount;
      unknown[nutrient] = unknownCount;
    }
    return NutritionAnalyticsTotals(
      values: Map.unmodifiable(values),
      knownCounts: Map.unmodifiable(known),
      unknownCounts: Map.unmodifiable(unknown),
    );
  }
}

double _itemNutrientValue(MealItem item, TrackedNutrient nutrient) =>
    switch (nutrient) {
      TrackedNutrient.calories => item.calories,
      TrackedNutrient.protein => item.protein,
      TrackedNutrient.carbohydrates => item.carbs,
      TrackedNutrient.fat => item.fats,
      TrackedNutrient.fiber => item.fiber,
      TrackedNutrient.sugar => item.sugar,
      TrackedNutrient.sodium => item.sodium,
      TrackedNutrient.potassium => item.potassium,
      TrackedNutrient.calcium => item.calcium,
      TrackedNutrient.magnesium => item.magnesium,
      TrackedNutrient.phosphorus => item.phosphorus,
    };

class _NutritionTargets {
  const _NutritionTargets({
    this.calories,
    this.protein,
    this.carbs,
    this.fats,
    this.fiber,
  });
  final double? calories, protein, carbs, fats, fiber;
  factory _NutritionTargets.from(
    DailyTargets recommended, {
    int? calories,
    int? protein,
    int? carbs,
    int? fats,
    int? fiber,
  }) => _NutritionTargets(
    calories: (calories ?? recommended.calories).toDouble(),
    protein: (protein ?? recommended.protein).toDouble(),
    carbs: (carbs ?? recommended.carbs).toDouble(),
    fats: (fats ?? recommended.fats).toDouble(),
    fiber: (fiber ?? recommended.fiber).toDouble(),
  );
}

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

class _MacrosTab extends StatelessWidget {
  const _MacrosTab({required this.totals, required this.targets});
  final NutritionAnalyticsTotals totals;
  final _NutritionTargets targets;
  @override
  Widget build(BuildContext context) {
    final knownEnergy = totals.carbs * 4 + totals.protein * 4 + totals.fats * 9;
    return ListView(
      key: const Key('nutrition-macros-tab'),
      padding: const EdgeInsets.all(20),
      children: [
        const _DayHeader(),
        const SizedBox(height: 24),
        if (!totals.isComplete(TrackedNutrient.carbohydrates) ||
            !totals.isComplete(TrackedNutrient.protein) ||
            !totals.isComplete(TrackedNutrient.fat))
          _CoverageNotice(
            text: _t(
              context,
              'Macro distribution uses evidenced carbohydrate, protein, and fat only.',
            ),
          ),
        _DistributionRow(
          label: _t(context, 'Carbohydrates'),
          value: totals.carbs * 4,
          total: knownEnergy,
          color: const Color(0xFF26B8B0),
        ),
        _DistributionRow(
          label: _t(context, 'Fat'),
          value: totals.fats * 9,
          total: knownEnergy,
          color: const Color(0xFF731A9D),
        ),
        _DistributionRow(
          label: _t(context, 'Protein'),
          value: totals.protein * 4,
          total: knownEnergy,
          color: const Color(0xFFFFB33C),
        ),
        const Divider(height: 40),
        _TableHeader(),
        _NutrientRow(
          label: _t(context, 'Carbohydrates'),
          total: totals.carbs,
          goal: targets.carbs,
          unit: 'g',
        ),
        _NutrientRow(
          label: _t(context, 'Fat'),
          total: totals.fats,
          goal: targets.fats,
          unit: 'g',
        ),
        _NutrientRow(
          label: _t(context, 'Protein'),
          total: totals.protein,
          goal: targets.protein,
          unit: 'g',
        ),
      ],
    );
  }
}

class _DayHeader extends ConsumerWidget {
  const _DayHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLogDateProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(selected);
    final isToday = DateUtils.isSameDay(day, today);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    void select(DateTime value) {
      ref.read(selectedLogDateProvider.notifier).state = DateUtils.dateOnly(
        value,
      );
    }

    return Semantics(
      container: true,
      label:
          '${_t(context, 'Day view')}: '
          '${MaterialLocalizations.of(context).formatFullDate(day)}',
      child: Row(
        children: [
          IconButton(
            tooltip: _t(context, 'Previous day'),
            onPressed: () => select(day.subtract(const Duration(days: 1))),
            icon: Icon(
              rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(2000),
                  lastDate: today,
                );
                if (picked != null) select(picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      _t(context, 'Day view'),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      isToday
                          ? _t(context, 'Today')
                          : MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(day),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _t(context, 'Next day'),
            onPressed: isToday
                ? null
                : () => select(day.add(const Duration(days: 1))),
            icon: Icon(
              rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Row(
      children: [
        const Spacer(),
        for (final text in ['Total', 'Goal', 'Left'])
          SizedBox(
            width: 64,
            child: Text(
              _t(context, text),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );
}

class _NutrientRow extends StatelessWidget {
  const _NutrientRow({
    required this.label,
    required this.total,
    required this.goal,
    required this.unit,
  });
  final String label, unit;
  final double? total;
  final double? goal;
  @override
  Widget build(BuildContext context) {
    final double? left = goal == null || total == null ? null : goal! - total!;
    String f(double? v) => v == null ? '—' : '${v.round()} $unit';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          for (final value in [total, goal, left])
            SizedBox(
              width: 64,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(f(value), textAlign: TextAlign.end),
              ),
            ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });
  final String label;
  final double value, total;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final share = total <= 0 ? 0.0 : (value / total).clamp(0, 1).toDouble();
    return Semantics(
      label: label,
      value: '${(share * 100).round()}%, ${value.round()}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Container(width: 16, height: 16, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(label)),
                Text('${(share * 100).round()}% · ${value.round()}'),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: share, color: color),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final double? value;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Text(value == null ? '—' : value!.round().toString()),
  );
}

String _t(BuildContext context, String key) =>
    _nutrientPresetCopy[Localizations.localeOf(context).languageCode]?[key] ??
    _copy[Localizations.localeOf(context).languageCode]?[key] ??
    AppLocalizations.of(context).text(_copy['en']![key] ?? key);

const _nutrientPresetCopy = <String, Map<String, String>>{
  'en': {
    'Heart Healthy': 'Heart Healthy',
    'Carb Conscious': 'Carb Conscious',
    'Saturated fat': 'Saturated fat',
    'Unknown': 'Unknown',
    'Custom nutrient goals': 'Custom nutrient goals',
  },
  'ar': {
    'Heart Healthy': 'صحي للقلب',
    'Carb Conscious': 'واعٍ بالكربوهيدرات',
    'Saturated fat': 'الدهون المشبعة',
    'Unknown': 'غير معروف',
    'Custom nutrient goals': 'أهداف المغذيات المخصصة',
  },
  'fr': {
    'Heart Healthy': 'Santé du cœur',
    'Carb Conscious': 'Maîtrise des glucides',
    'Saturated fat': 'Graisses saturées',
    'Unknown': 'Inconnu',
    'Custom nutrient goals': 'Objectifs nutritionnels personnalisés',
  },
  'es': {
    'Heart Healthy': 'Salud cardiovascular',
    'Carb Conscious': 'Control de carbohidratos',
    'Saturated fat': 'Grasa saturada',
    'Unknown': 'Desconocido',
    'Custom nutrient goals': 'Objetivos de nutrientes personalizados',
  },
  'tr': {
    'Heart Healthy': 'Kalp dostu',
    'Carb Conscious': 'Karbonhidrat kontrollü',
    'Saturated fat': 'Doymuş yağ',
    'Unknown': 'Bilinmiyor',
    'Custom nutrient goals': 'Özel besin hedefleri',
  },
};
const _copy = <String, Map<String, String>>{
  'en': {
    'Nutrition': 'Nutrition',
    'Calories': 'Calories',
    'Nutrients': 'Nutrients',
    'Macros': 'Macros',
    'Try again': 'Try again',
    'Export': 'Export',
    'Previous day': 'Previous day',
    'Next day': 'Next day',
    'Nutrition goals could not be loaded.':
        'Nutrition goals could not be loaded.',
    'No foods logged for this day.': 'No foods logged for this day.',
    'Log food to see evidence-backed nutrition totals.':
        'Log food to see evidence-backed nutrition totals.',
    'Log food': 'Log food',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'Calorie total includes evidenced entries only; some entries are unknown.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'Macro distribution uses evidenced carbohydrate, protein, and fat only.',
    'Day view': 'Day view',
    'Today': 'Today',
    'Total': 'Total',
    'Goal': 'Goal',
    'Left': 'Left',
    'Total calories': 'Total calories',
    'Protein': 'Protein',
    'Carbohydrates': 'Carbohydrates',
    'Fiber': 'Fiber',
    'Sugar': 'Sugar',
    'Fat': 'Fat',
    'Sodium': 'Sodium',
    'Potassium': 'Potassium',
    'Calcium': 'Calcium',
    'Magnesium': 'Magnesium',
    'Phosphorus': 'Phosphorus',
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snacks',
    'other': 'Other',
    'Your recorded nutrients': 'Your recorded nutrients',
    'General adult reference': 'General adult reference values',
    'Food analysis': 'Food analysis',
    'Choose a nutrient': 'Choose a nutrient',
    'Nutrient': 'Nutrient',
    'Top contributors': 'Top contributors',
    'Unknown food': 'Unknown food',
    'Known total': 'Known total',
    'Entries with unknown values': 'Entries with unknown values',
    'Logged entries': 'Logged entries',
    'Verified snapshot': 'Verified snapshot',
    'Unverified snapshot': 'Unverified snapshot',
    'No evidenced values are available.': 'No evidenced values are available.',
    'No logged item has evidence for this nutrient.':
        'No logged item has evidence for this nutrient.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.',
  },
  'ar': {
    'Nutrition': 'التغذية',
    'Calories': 'السعرات',
    'Nutrients': 'العناصر الغذائية',
    'Macros': 'الماكروز',
    'Try again': 'إعادة المحاولة',
    'Export': 'تصدير',
    'Previous day': 'اليوم السابق',
    'Next day': 'اليوم التالي',
    'Nutrition goals could not be loaded.': 'تعذر تحميل أهداف التغذية.',
    'No foods logged for this day.': 'لا توجد أطعمة مسجلة لهذا اليوم.',
    'Log food to see evidence-backed nutrition totals.':
        'سجّل طعامًا لعرض إجماليات التغذية المدعومة بالدليل.',
    'Log food': 'تسجيل طعام',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'يشمل إجمالي السعرات الإدخالات المدعومة بالدليل فقط؛ بعض القيم غير معروفة.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'يستخدم توزيع الماكروز الكربوهيدرات والبروتين والدهون المدعومة بالدليل فقط.',
    'Day view': 'عرض اليوم',
    'Today': 'اليوم',
    'Total': 'الإجمالي',
    'Goal': 'الهدف',
    'Left': 'المتبقي',
    'Total calories': 'إجمالي السعرات',
    'Protein': 'البروتين',
    'Carbohydrates': 'الكربوهيدرات',
    'Fiber': 'الألياف',
    'Sugar': 'السكر',
    'Fat': 'الدهون',
    'Sodium': 'الصوديوم',
    'Potassium': 'البوتاسيوم',
    'Calcium': 'الكالسيوم',
    'Magnesium': 'المغنيسيوم',
    'Phosphorus': 'الفوسفور',
    'breakfast': 'الإفطار',
    'lunch': 'الغداء',
    'dinner': 'العشاء',
    'snack': 'الوجبات الخفيفة',
    'other': 'أخرى',
    'Your recorded nutrients': 'العناصر الغذائية المسجلة لديك',
    'General adult reference': 'قيم مرجعية عامة للبالغين',
    'Food analysis': 'تحليل الطعام',
    'Choose a nutrient': 'اختر عنصرًا غذائيًا',
    'Nutrient': 'العنصر الغذائي',
    'Top contributors': 'أبرز مصادر العنصر المسجلة',
    'Unknown food': 'طعام غير معروف',
    'Known total': 'الإجمالي المعروف',
    'Entries with unknown values': 'إدخالات بقيم غير معروفة',
    'Logged entries': 'مرات التسجيل',
    'Verified snapshot': 'لقطة موثقة',
    'Unverified snapshot': 'لقطة غير موثقة',
    'No evidenced values are available.': 'لا تتوفر قيم مدعومة بدليل.',
    'No logged item has evidence for this nutrient.':
        'لا يحتوي أي عنصر مسجل على دليل لهذا العنصر الغذائي.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'يصف هذا التحليل مساهمات العناصر الغذائية المسجلة ولا يصنف الطعام على أنه جيد أو سيئ.',
  },
  'fr': {
    'Nutrition': 'Nutrition',
    'Calories': 'Calories',
    'Nutrients': 'Nutriments',
    'Macros': 'Macros',
    'Try again': 'Réessayer',
    'Export': 'Exporter',
    'Previous day': 'Jour précédent',
    'Next day': 'Jour suivant',
    'Nutrition goals could not be loaded.':
        'Impossible de charger les objectifs nutritionnels.',
    'No foods logged for this day.': 'Aucun aliment enregistré ce jour.',
    'Log food to see evidence-backed nutrition totals.':
        'Enregistrez un aliment pour afficher des totaux nutritionnels documentés.',
    'Log food': 'Enregistrer un aliment',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'Le total calorique inclut uniquement les entrées documentées ; certaines valeurs sont inconnues.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'La répartition utilise uniquement les glucides, protéines et lipides documentés.',
    'Day view': 'Vue du jour',
    'Today': "Aujourd’hui",
    'Total': 'Total',
    'Goal': 'Objectif',
    'Left': 'Restant',
    'Total calories': 'Calories totales',
    'Protein': 'Protéines',
    'Carbohydrates': 'Glucides',
    'Fiber': 'Fibres',
    'Sugar': 'Sucre',
    'Fat': 'Lipides',
    'Sodium': 'Sodium',
    'Potassium': 'Potassium',
    'Calcium': 'Calcium',
    'Magnesium': 'Magnésium',
    'Phosphorus': 'Phosphore',
    'breakfast': 'Petit-déjeuner',
    'lunch': 'Déjeuner',
    'dinner': 'Dîner',
    'snack': 'Collations',
    'other': 'Autres',
    'Your recorded nutrients': 'Vos nutriments enregistrés',
    'General adult reference': 'Valeurs générales de référence pour adultes',
    'Food analysis': 'Analyse des aliments',
    'Choose a nutrient': 'Choisir un nutriment',
    'Nutrient': 'Nutriment',
    'Top contributors': 'Principales contributions',
    'Unknown food': 'Aliment inconnu',
    'Known total': 'Total connu',
    'Entries with unknown values': 'Entrées aux valeurs inconnues',
    'Logged entries': 'Entrées enregistrées',
    'Verified snapshot': 'Instantané vérifié',
    'Unverified snapshot': 'Instantané non vérifié',
    'No evidenced values are available.':
        'Aucune valeur documentée disponible.',
    'No logged item has evidence for this nutrient.':
        'Aucun aliment enregistré ne documente ce nutriment.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'Cette analyse décrit les contributions enregistrées sans qualifier les aliments de bons ou mauvais.',
  },
  'es': {
    'Nutrition': 'Nutrición',
    'Calories': 'Calorías',
    'Nutrients': 'Nutrientes',
    'Macros': 'Macros',
    'Try again': 'Reintentar',
    'Export': 'Exportar',
    'Previous day': 'Día anterior',
    'Next day': 'Día siguiente',
    'Nutrition goals could not be loaded.':
        'No se pudieron cargar los objetivos nutricionales.',
    'No foods logged for this day.': 'No hay alimentos registrados este día.',
    'Log food to see evidence-backed nutrition totals.':
        'Registra un alimento para ver totales nutricionales documentados.',
    'Log food': 'Registrar alimento',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'El total calórico incluye solo registros documentados; algunos valores son desconocidos.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'La distribución usa solo carbohidratos, proteínas y grasas documentados.',
    'Day view': 'Vista diaria',
    'Today': 'Hoy',
    'Total': 'Total',
    'Goal': 'Objetivo',
    'Left': 'Restante',
    'Total calories': 'Calorías totales',
    'Protein': 'Proteína',
    'Carbohydrates': 'Carbohidratos',
    'Fiber': 'Fibra',
    'Sugar': 'Azúcar',
    'Fat': 'Grasa',
    'Sodium': 'Sodio',
    'Potassium': 'Potasio',
    'Calcium': 'Calcio',
    'Magnesium': 'Magnesio',
    'Phosphorus': 'Fósforo',
    'breakfast': 'Desayuno',
    'lunch': 'Almuerzo',
    'dinner': 'Cena',
    'snack': 'Tentempiés',
    'other': 'Otros',
    'Your recorded nutrients': 'Tus nutrientes registrados',
    'General adult reference': 'Valores generales de referencia para adultos',
    'Food analysis': 'Análisis de alimentos',
    'Choose a nutrient': 'Elige un nutriente',
    'Nutrient': 'Nutriente',
    'Top contributors': 'Principales contribuciones',
    'Unknown food': 'Alimento desconocido',
    'Known total': 'Total conocido',
    'Entries with unknown values': 'Registros con valores desconocidos',
    'Logged entries': 'Registros',
    'Verified snapshot': 'Datos verificados',
    'Unverified snapshot': 'Datos no verificados',
    'No evidenced values are available.':
        'No hay valores documentados disponibles.',
    'No logged item has evidence for this nutrient.':
        'Ningún alimento registrado tiene datos de este nutriente.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'Este análisis describe las contribuciones registradas sin clasificar alimentos como buenos o malos.',
  },
  'tr': {
    'Nutrition': 'Beslenme',
    'Calories': 'Kalori',
    'Nutrients': 'Besin öğeleri',
    'Macros': 'Makrolar',
    'Try again': 'Tekrar dene',
    'Export': 'Dışa aktar',
    'Previous day': 'Önceki gün',
    'Next day': 'Sonraki gün',
    'Nutrition goals could not be loaded.': 'Beslenme hedefleri yüklenemedi.',
    'No foods logged for this day.': 'Bu gün için kayıtlı yiyecek yok.',
    'Log food to see evidence-backed nutrition totals.':
        'Kanıta dayalı beslenme toplamlarını görmek için yiyecek kaydedin.',
    'Log food': 'Yiyecek kaydet',
    'Calorie total includes evidenced entries only; some entries are unknown.':
        'Kalori toplamı yalnızca kanıtlı kayıtları içerir; bazı değerler bilinmiyor.',
    'Macro distribution uses evidenced carbohydrate, protein, and fat only.':
        'Makro dağılımı yalnızca kanıtlı karbonhidrat, protein ve yağı kullanır.',
    'Day view': 'Gün görünümü',
    'Today': 'Bugün',
    'Total': 'Toplam',
    'Goal': 'Hedef',
    'Left': 'Kalan',
    'Total calories': 'Toplam kalori',
    'Protein': 'Protein',
    'Carbohydrates': 'Karbonhidrat',
    'Fiber': 'Lif',
    'Sugar': 'Şeker',
    'Fat': 'Yağ',
    'Sodium': 'Sodyum',
    'Potassium': 'Potasyum',
    'Calcium': 'Kalsiyum',
    'Magnesium': 'Magnezyum',
    'Phosphorus': 'Fosfor',
    'breakfast': 'Kahvaltı',
    'lunch': 'Öğle yemeği',
    'dinner': 'Akşam yemeği',
    'snack': 'Atıştırmalıklar',
    'other': 'Diğer',
    'Your recorded nutrients': 'Kaydedilen besin öğeleriniz',
    'General adult reference': 'Yetişkinler için genel referans değerleri',
    'Food analysis': 'Yiyecek analizi',
    'Choose a nutrient': 'Bir besin öğesi seçin',
    'Nutrient': 'Besin öğesi',
    'Top contributors': 'En büyük katkılar',
    'Unknown food': 'Bilinmeyen yiyecek',
    'Known total': 'Bilinen toplam',
    'Entries with unknown values': 'Değeri bilinmeyen kayıtlar',
    'Logged entries': 'Kayıt sayısı',
    'Verified snapshot': 'Doğrulanmış anlık kayıt',
    'Unverified snapshot': 'Doğrulanmamış anlık kayıt',
    'No evidenced values are available.': 'Kanıtlı bir değer bulunmuyor.',
    'No logged item has evidence for this nutrient.':
        'Kayıtlı hiçbir yiyecekte bu besin öğesi için kanıt yok.',
    'This analysis describes recorded nutrient contributions. It does not label foods as good or bad.':
        'Bu analiz kayıtlı besin katkılarını açıklar; yiyecekleri iyi veya kötü diye sınıflandırmaz.',
  },
};
