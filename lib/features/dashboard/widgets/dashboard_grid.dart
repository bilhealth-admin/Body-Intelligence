import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/bil_engine.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/intelligence_engine.dart';
import '../../profile/providers/user_profile_provider.dart';
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
    if ([
      profileAsync,
      weightsAsync,
      mealsAsync,
      waterAsync,
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
        waterAsync.hasError) {
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
    final progressDenominator = (profile.currentWeight - profile.targetWeight)
        .abs();
    final progress = progressDenominator == 0
        ? 1.0
        : ((profile.currentWeight - currentWeight).abs() / progressDenominator)
              .clamp(0.0, 1.0);
    final goalDate = intelligence.goalDate;

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
              value: '${currentWeight.toStringAsFixed(1)} kg',
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
      ],
    );
  }
}
