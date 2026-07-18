import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/date_keys.dart';
import '../../app/localization/app_localizations.dart';
import '../../core/units/measurement_units.dart';
import '../../engine/intelligence_engine.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../weight/providers/weight_provider.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightsAsync = ref.watch(weightHistoryProvider);
    final mealsAsync = ref.watch(allMealsProvider);
    final waterAsync = ref.watch(allWaterProvider);
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final weightUnit = UnitConverter.weightUnit(system);
    if (weightsAsync.isLoading ||
        mealsAsync.isLoading ||
        waterAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (weightsAsync.hasError || mealsAsync.hasError || waterAsync.hasError) {
      return const Scaffold(
        body: Center(child: Text('Analytics data could not be loaded.')),
      );
    }
    final weights = (weightsAsync.value ?? const []).reversed.toList();
    final meals = mealsAsync.value ?? const [];
    final water = waterAsync.value ?? const [];
    final caloriesByDay = <String, double>{};
    final proteinByDay = <String, double>{};
    for (final meal in meals) {
      caloriesByDay.update(
        meal.meal.dayKey,
        (value) =>
            value + meal.items.fold(0, (sum, item) => sum + item.calories),
        ifAbsent: () => meal.items.fold(0, (sum, item) => sum + item.calories),
      );
      proteinByDay.update(
        meal.meal.dayKey,
        (value) =>
            value + meal.items.fold(0, (sum, item) => sum + item.protein),
        ifAbsent: () => meal.items.fold(0, (sum, item) => sum + item.protein),
      );
    }
    final waterByDay = <String, int>{};
    for (final entry in water) {
      waterByDay.update(
        entry.dayKey,
        (value) => value + entry.amountMl,
        ifAbsent: () => entry.amountMl,
      );
    }
    final trackedDays = {...caloriesByDay.keys, ...waterByDay.keys}.length;
    final rate = IntelligenceEngine.weeklyRate(
      weights.map((row) => row.weight).toList(),
    );
    final recentWeights = weights.length > 30
        ? weights.sublist(weights.length - 30)
        : weights;
    final maxWeight = recentWeights.isEmpty
        ? 1.0
        : recentWeights
              .map((row) => row.weight)
              .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Analytics'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(
            title: '7 / 30 day summary',
            lines: [
              '$trackedDays nutrition or hydration days recorded',
              rate == null
                  ? 'Weight trend needs at least four entries'
                  : '${rate >= 0 ? '+' : ''}${UnitConverter.weightFromKg(rate, system).toStringAsFixed(2)} $weightUnit/week smoothed direction',
              '${caloriesByDay.length} days with calculated meal totals',
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Weight over time',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (recentWeights.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Add weight entries to see a trend.'),
            )
          else
            ...recentWeights.map(
              (row) => _MetricBar(
                label: dayKeyFor(row.date),
                value: UnitConverter.weightFromKg(row.weight, system),
                maximum: UnitConverter.weightFromKg(maxWeight, system),
                suffix: weightUnit,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Calories and protein by day',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (caloriesByDay.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Add meals to see nutrition consistency.'),
            )
          else
            ...caloriesByDay.keys
                .toList()
                .reversed
                .take(30)
                .map(
                  (day) => ListTile(
                    title: Text(day),
                    subtitle: Text(
                      '${caloriesByDay[day]!.round()} kcal · ${proteinByDay[day]!.toStringAsFixed(1)} g protein',
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          Text(
            'Water adherence records',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ...waterByDay.keys
              .toList()
              .reversed
              .take(30)
              .map(
                (day) => _MetricBar(
                  label: day,
                  value: waterByDay[day]!.toDouble(),
                  maximum: 3000,
                  suffix: 'ml',
                ),
              ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.lines});
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...lines.map(Text.new),
        ],
      ),
    ),
  );
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.maximum,
    required this.suffix,
  });
  final String label;
  final double value;
  final double maximum;
  final String suffix;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    subtitle: LinearProgressIndicator(value: (value / maximum).clamp(0, 1)),
    trailing: Text('${value.toStringAsFixed(1)} $suffix'),
  );
}
