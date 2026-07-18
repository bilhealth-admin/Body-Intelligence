import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/date_keys.dart';
import '../../app/localization/app_localizations.dart';
import '../../core/units/measurement_units.dart';
import '../../engine/intelligence_engine.dart';
import '../../engine/recovery_engine.dart';
import '../../engine/weekly_review_engine.dart';
import '../dashboard/providers/dashboard_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../life_context/providers/life_context_provider.dart';
import '../weight/providers/weight_provider.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => arabic ? ar : en;
    final weightsAsync = ref.watch(weightHistoryProvider);
    final mealsAsync = ref.watch(allMealsProvider);
    final waterAsync = ref.watch(allWaterProvider);
    final contextsAsync = ref.watch(insightLifeContextProvider);
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final weightUnit = UnitConverter.weightUnit(system);
    if (weightsAsync.isLoading ||
        mealsAsync.isLoading ||
        waterAsync.isLoading ||
        contextsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (weightsAsync.hasError ||
        mealsAsync.hasError ||
        waterAsync.hasError ||
        contextsAsync.hasError) {
      return Scaffold(
        body: Center(
          child: Text(
            tr(
              'Analytics data could not be loaded.',
              'تعذر تحميل بيانات التحليلات.',
            ),
          ),
        ),
      );
    }
    final weights = (weightsAsync.value ?? const []).reversed.toList();
    final meals = mealsAsync.value ?? const [];
    final water = waterAsync.value ?? const [];
    final contexts = contextsAsync.value ?? const [];
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
    final cutoffKey = dayKeyFor(
      DateTime.now().subtract(const Duration(days: 6)),
    );
    final recentWeightDays = weights
        .where((row) => dayKeyFor(row.date).compareTo(cutoffKey) >= 0)
        .map((row) => dayKeyFor(row.date))
        .toSet();
    final recentMealDays = caloriesByDay.keys
        .where((day) => day.compareTo(cutoffKey) >= 0)
        .toSet();
    final recentWaterDays = waterByDay.keys
        .where((day) => day.compareTo(cutoffKey) >= 0)
        .toSet();
    final recentContextDays = contexts
        .where((row) => row.dayKey.compareTo(cutoffKey) >= 0)
        .map((row) => row.dayKey)
        .toSet();
    final weekly = WeeklyReviewEngine.evaluate(
      weightDays: recentWeightDays.length,
      nutritionDays: recentMealDays.length,
      waterDays: recentWaterDays.length,
      contextDays: recentContextDays.length,
      weeklyWeightChangeKg: rate,
    );
    final activityDates = <DateTime>[
      ...weights.map((row) => row.date),
      ...meals.map((row) => row.meal.date),
      ...water.map((row) => row.occurredAt),
      ...contexts.map((row) => row.occurredAt),
    ]..sort();
    final recovery = RecoveryEngine.evaluate(
      now: DateTime.now(),
      lastTrackedAt: activityDates.lastOrNull,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Analytics'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (recovery.state != RecoveryState.current)
            _SummaryCard(
              title: arabic
                  ? recovery.daysAway == 0
                        ? 'ابدأ اليوم من جديد'
                        : 'مرحبًا بعودتك — لا حاجة لملء الأيام الناقصة'
                  : recovery.title,
              lines: [
                if (recovery.daysAway > 0)
                  tr(
                    '${recovery.daysAway} days since the latest local record',
                    '${recovery.daysAway} يومًا منذ أحدث سجل محلي',
                  ),
                ...(arabic
                    ? const [
                        'ابدأ اليوم من جديد',
                        'سجّل الوزن',
                        'سجّل أول وجبة',
                      ]
                    : recovery.actions),
              ],
            ),
          if (recovery.state != RecoveryState.current)
            const SizedBox(height: 12),
          _SummaryCard(
            title: tr('Weekly review', 'المراجعة الأسبوعية'),
            lines: [
              tr(
                '${weekly.trackedDays} of 7 days with at least one core record',
                '${weekly.trackedDays} من 7 أيام بها سجل أساسي واحد على الأقل',
              ),
              if (arabic)
                rate == null
                    ? 'لا توجد أدلة وزن متقاربة كافية لاتجاه أسبوعي.'
                    : 'الاتجاه الأسبوعي الممهّد: ${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)} كجم. لا يحدد هذا تغير الدهون أو العضلات.'
              else
                weekly.summary,
              if (arabic)
                weekly.missingData.isNotEmpty
                    ? 'حسّن مصدر بيانات ناقصًا واحدًا قبل تغيير الخطة.'
                    : 'حافظ على ثبات الخطة وقارن أسبوعًا كاملًا آخر.'
              else
                weekly.nextDecision,
              ...(arabic
                  ? [
                      if (weekly.weightDays < 4)
                        'تحسّن 4 أيام وزن على الأقل تفسير الاتجاه',
                      if (weekly.nutritionDays < 5)
                        'تحسّن أيام الوجبات المكتملة فهم المدخول',
                      if (weekly.waterDays < 5)
                        'تحسّن أيام الترطيب فهم الالتزام',
                    ]
                  : weekly.missingData),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: tr('7 / 30 day summary', 'ملخص 7 / 30 يومًا'),
            lines: [
              tr(
                '$trackedDays nutrition or hydration days recorded',
                'تم تسجيل التغذية أو الترطيب في $trackedDays يومًا',
              ),
              rate == null
                  ? tr(
                      'Weight trend needs at least four entries',
                      'يحتاج اتجاه الوزن إلى أربعة قياسات على الأقل',
                    )
                  : '${rate >= 0 ? '+' : ''}${UnitConverter.weightFromKg(rate, system).toStringAsFixed(2)} $weightUnit/${tr('week', 'أسبوع')} ${tr('smoothed direction', 'اتجاه ممهّد')}',
              tr(
                '${caloriesByDay.length} days with calculated meal totals',
                '${caloriesByDay.length} يومًا بإجماليات وجبات محسوبة',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr('Weight over time', 'الوزن عبر الزمن'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (recentWeights.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                tr(
                  'Add weight entries to see a trend.',
                  'أضف قياسات وزن لرؤية الاتجاه.',
                ),
              ),
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
            tr('Calories and protein by day', 'السعرات والبروتين حسب اليوم'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (caloriesByDay.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                tr(
                  'Add meals to see nutrition consistency.',
                  'أضف وجبات لرؤية انتظام التغذية.',
                ),
              ),
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
                      '${caloriesByDay[day]!.round()} ${tr('kcal', 'سعرة')} · ${proteinByDay[day]!.toStringAsFixed(1)} ${tr('g protein', 'غ بروتين')}',
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          Text(
            tr('Water adherence records', 'سجلات الالتزام بالماء'),
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
