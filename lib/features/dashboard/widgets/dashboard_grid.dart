import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/bil_engine.dart';
import '../../../core/units/measurement_units.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/body_twin_engine.dart';
import '../../../engine/data_honesty_engine.dart';
import '../../../engine/intelligence_engine.dart';
import '../../../engine/one_best_action_engine.dart';
import '../../../engine/what_changed_engine.dart';
import '../../../data/database/date_keys.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../providers/dashboard_provider.dart';
import 'stat_card.dart';

class DashboardGrid extends ConsumerWidget {
  const DashboardGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final weightsAsync = ref.watch(weightHistoryProvider);
    final mealsAsync = ref.watch(todayMealsProvider);
    final waterAsync = ref.watch(todayWaterProvider);
    final allMealsAsync = ref.watch(allMealsProvider);
    final allWaterAsync = ref.watch(allWaterProvider);
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    if ([
      profileAsync,
      weightsAsync,
      mealsAsync,
      waterAsync,
      allMealsAsync,
      allWaterAsync,
    ].any((value) => value.isLoading)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (profileAsync.hasError ||
        weightsAsync.hasError ||
        mealsAsync.hasError ||
        waterAsync.hasError ||
        allMealsAsync.hasError ||
        allWaterAsync.hasError) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Some local dashboard data could not be loaded.'),
        ),
      );
    }
    final profile = profileAsync.value;
    if (profile == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Complete your profile to calculate personalized targets.',
          ),
        ),
      );
    }
    final weights = weightsAsync.value ?? const [];
    final meals = mealsAsync.value ?? const [];
    final waterRows = waterAsync.value ?? const [];
    final allMeals = allMealsAsync.value ?? const [];
    final allWater = allWaterAsync.value ?? const [];
    final items = meals.expand((meal) => meal.items).toList();
    final calories = items.fold<double>(0, (sum, item) => sum + item.calories);
    final protein = items.fold<double>(0, (sum, item) => sum + item.protein);
    final sodium = items.fold<double>(0, (sum, item) => sum + item.sodium);
    final water = waterRows.fold<int>(0, (sum, item) => sum + item.amountMl);
    final currentWeight = weights.firstOrNull?.weight ?? profile.currentWeight;
    final goalType = profile.targetWeight < currentWeight
        ? 'lose'
        : profile.targetWeight > currentWeight
        ? 'gain'
        : 'maintain';
    final body = BodyProfile(
      age: profile.age,
      gender: profile.gender,
      height: profile.height,
      weight: currentWeight,
      targetWeight: profile.targetWeight,
      activityLevel: profile.activityLevel,
      exercises: profile.exercises,
      goalType: goalType,
    );
    final bil = BILEngine.calculate(
      profile: body,
      eatenCalories: calories.round(),
      eatenProtein: protein.round(),
      drankWater: water,
    );
    final chronological = weights.reversed.map((row) => row.weight).toList();
    final mealDays = allMeals.map((row) => row.meal.dayKey).toSet();
    final waterDays = allWater.map((row) => row.dayKey).toSet();
    final weightDays = weights
        .map((row) => row.dayKey ?? dayKeyFor(row.date))
        .toSet();
    final observedDays = {...mealDays, ...waterDays, ...weightDays};
    final comparableWeightDays = weights
        .where((row) => row.measurementContext != 'differentConditions')
        .length;
    final intelligence = IntelligenceEngine.evaluate(
      calorieTarget: bil.targets.calories,
      proteinTarget: bil.targets.protein,
      waterTarget: bil.targets.water,
      calories: calories,
      protein: protein,
      waterMl: water,
      chronologicalWeights: chronological,
      goalWeight: profile.targetWeight,
      sodium: sodium,
      trackedDays: items.isEmpty && waterRows.isEmpty ? 0 : 1,
    );
    final honesty = DataHonestyEngine.evaluate(
      observationDays: observedDays.length,
      weightDays: weightDays.length,
      nutritionDays: mealDays.length,
      waterDays: waterDays.length,
      consistentConditionDays: comparableWeightDays,
    );
    final bestAction = OneBestActionEngine.choose(
      weighedToday: weightDays.contains(dayKeyFor(DateTime.now())),
      loggingComplete: meals.isNotEmpty,
      protein: protein,
      proteinTarget: bil.targets.protein,
      waterMl: water,
      waterTarget: bil.targets.water,
      trackedDays: observedDays.length,
    );
    final changed = WhatChangedEngine.compare(
      chronologicalWeights: chronological,
      comparableConditions:
          weights.length >= 2 &&
          weights[0].measurementContext == weights[1].measurementContext &&
          weights[0].measurementContext != 'differentConditions',
    );
    final twin = BodyTwinEngine.simulate(
      calorieTarget: bil.targets.calories,
      tdee: bil.tdee.round(),
      weightDays: weightDays.length,
      nutritionDays: mealDays.length,
      observationDays: observedDays.length,
    );
    final progressDenominator = (profile.currentWeight - profile.targetWeight)
        .abs();
    final progress = progressDenominator == 0
        ? 1.0
        : ((profile.currentWeight - currentWeight).abs() / progressDenominator)
              .clamp(0.0, 1.0);
    final goalDate = intelligence.goalDate;
    Future<void> respondToAction(String response) async {
      final repository = ref.read(decisionMemoryRepositoryProvider);
      final id = await repository.rememberAction(bestAction);
      await repository.respond(id, response);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response == 'done'
                  ? 'Marked done. BIL will not assume an outcome without your later feedback.'
                  : 'Your response was saved locally and can be deleted from Decision Memory.',
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            StatCard(
              title: 'Weight',
              value:
                  '${UnitConverter.weightFromKg(currentWeight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
              icon: Icons.monitor_weight,
              color: Colors.blue,
            ),
            StatCard(
              title: 'Calories',
              value: '${calories.round()} / ${bil.targets.calories}',
              icon: Icons.local_fire_department,
              color: Colors.orange,
            ),
            StatCard(
              title: 'Protein',
              value: '${protein.round()} / ${bil.targets.protein} g',
              icon: Icons.fitness_center,
              color: Colors.green,
            ),
            StatCard(
              title: 'Water',
              value: '$water / ${bil.targets.water} ml',
              icon: Icons.water_drop,
              color: Colors.cyan,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Goal progress ${(progress * 100).round()}%'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Text(
                  'Estimated TDEE ${bil.tdee.round()} kcal · planned ${goalType == 'lose'
                      ? 'deficit'
                      : goalType == 'gain'
                      ? 'surplus'
                      : 'maintenance'} ${bil.targets.calories - bil.tdee.round()} kcal',
                ),
                Text(
                  goalDate == null
                      ? 'Goal date: more consistent weight data needed'
                      : 'Estimated goal date: ${goalDate.year}-${goalDate.month.toString().padLeft(2, '0')}-${goalDate.day.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(intelligence.score?.toString() ?? '—'),
            ),
            title: Text(intelligence.insights.first.title),
            subtitle: Text(
              '${intelligence.insights.first.explanation}\n${intelligence.insights.first.suggestedAction}',
            ),
            isThreeLine: true,
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'One best action',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  bestAction.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(bestAction.reason),
                const SizedBox(height: 8),
                Text('Evidence: ${bestAction.evidence.join(' · ')}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => respondToAction('accepted'),
                      child: const Text('Accept'),
                    ),
                    OutlinedButton(
                      onPressed: () => respondToAction('done'),
                      child: const Text('Done'),
                    ),
                    TextButton(
                      onPressed: () => respondToAction('notSuitable'),
                      child: const Text('Not suitable today'),
                    ),
                    TextButton(
                      onPressed: () => respondToAction('dismissed'),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ExpansionTile(
            leading: CircleAvatar(child: Text('${honesty.score}')),
            title: const Text('Data honesty'),
            subtitle: Text(
              '${honesty.reliability.name} reliability · tap to see what is missing',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (honesty.strengths.isNotEmpty)
                Text('Evidence: ${honesty.strengths.join(' · ')}'),
              if (honesty.missing.isNotEmpty)
                Text('Improve confidence: ${honesty.missing.join(' · ')}'),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            title: const Text('What changed today?'),
            subtitle: Text(changed.summary),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (changed.evidence.isNotEmpty)
                Text('Evidence: ${changed.evidence.join(' · ')}'),
              Text('Other explanations: ${changed.alternatives.join(' · ')}'),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            title: const Text('Body Twin'),
            subtitle: Text(
              twin.sufficient
                  ? 'Cautious scenario available from your local evidence'
                  : 'Learning safely · ${twin.requiredData.join(' · ')}',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (twin.scenario != null) ...[
                Text(
                  'Expected planning direction: ${twin.scenario!.expectedWeeklyKg.toStringAsFixed(2)} kg/week',
                ),
                Text(
                  'Cautious range: ${twin.scenario!.cautiousLowKg.toStringAsFixed(2)} to ${twin.scenario!.cautiousHighKg.toStringAsFixed(2)} kg/week',
                ),
                Text('Assumptions: ${twin.scenario!.assumptions.join(' · ')}'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
