import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/date_keys.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/theme/premium_design_tokens.dart';
import '../../core/units/measurement_units.dart';
import '../../engine/progress_analysis.dart';
import '../../engine/personal_baseline_engine.dart';
import '../../engine/recovery_engine.dart';
import '../../engine/weekly_review_engine.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../../shared/widgets/premium_surface.dart';

import '../dashboard/providers/dashboard_provider.dart';
import '../profile/providers/user_profile_provider.dart';
import '../life_context/providers/life_context_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'widgets/analytics_range_selector.dart';
import 'localized_confidence.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  AnalyticsRange range = AnalyticsRange.thirtyDays;

  @override
  Widget build(BuildContext context) {
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
        body: ActionableErrorState(
          title: tr(
            'Analytics data could not be loaded.',
            'تعذر تحميل بيانات التحليلات.',
          ),
          onRetry: () {
            ref.invalidate(weightHistoryProvider);
            ref.invalidate(allMealsProvider);
            ref.invalidate(allWaterProvider);
            ref.invalidate(insightLifeContextProvider);
          },
        ),
      );
    }
    final allWeights = (weightsAsync.value ?? const []).reversed.toList();
    final allMeals = mealsAsync.value ?? const [];
    final allWater = waterAsync.value ?? const [];
    final allContexts = contextsAsync.value ?? const [];
    final start = range.days == null
        ? null
        : DateTime.now().subtract(Duration(days: range.days! - 1));
    bool included(DateTime date) =>
        start == null || dayKeyFor(date).compareTo(dayKeyFor(start)) >= 0;
    final weights = allWeights.where((row) => included(row.date)).toList();
    final meals = allMeals.where((row) => included(row.meal.date)).toList();
    final water = allWater.where((row) => included(row.occurredAt)).toList();
    final contexts = allContexts
        .where((row) => included(row.occurredAt))
        .toList();
    final caloriesByDay = <String, double>{};
    final proteinByDay = <String, double>{};
    final sodiumByDay = <String, double>{};
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
      sodiumByDay.update(
        meal.meal.dayKey,
        (value) => value + meal.items.fold(0, (sum, item) => sum + item.sodium),
        ifAbsent: () => meal.items.fold(0, (sum, item) => sum + item.sodium),
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
    final progress = ProgressAnalysis.evaluate(
      samples: weights
          .map((row) => ProgressSample(date: row.date, weightKg: row.weight))
          .toList(),
    );
    final rate = progress.weeklyDirectionKg;
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
      ...allWeights.map((row) => row.date),
      ...allMeals.map((row) => row.meal.date),
      ...allWater.map((row) => row.occurredAt),
      ...allContexts.map((row) => row.occurredAt),
    ]..sort();
    final recovery = RecoveryEngine.evaluate(
      now: DateTime.now(),
      lastTrackedAt: activityDates.lastOrNull,
    );
    final baseline = PersonalBaselineEngine.evaluate(
      caloriesByDay: caloriesByDay,
      proteinByDay: proteinByDay,
      sodiumByDay: sodiumByDay,
      waterByDay: waterByDay.map(
        (key, value) => MapEntry(key, value.toDouble()),
      ),
      weightByDay: {
        for (final row in allWeights) dayKeyFor(row.date): row.weight,
      },
      currentStartDay: cutoffKey,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Analytics'))),
      body: ListView(
        padding: PremiumDesignTokens.screenPadding,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.strings.text('Analytics overview'),
              style: PremiumDesignTokens.screenHeading(context),
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          AnalyticsRangeSelector(
            value: range,
            onChanged: (value) => setState(() => range = value),
          ),
          const SizedBox(height: 12),
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
            const SizedBox(height: PremiumDesignTokens.spaceSm),
          _SummaryCard(
            title: tr('Your personal baseline', 'خطك الأساسي الشخصي'),
            lines: baseline.sufficient
                ? [
                    tr(
                      'Compared with your own earlier records · ${localizedBaselineConfidence(baseline.confidence, arabic: false)} confidence',
                      'مقارنة بسجلاتك السابقة أنت · ثقة ${localizedBaselineConfidence(baseline.confidence, arabic: true)}',
                    ),
                    ...baseline.comparisons.map((item) {
                      final sign = item.change >= 0 ? '+' : '';
                      return '${tr(item.metric, switch (item.metric) {
                        'Calories' => 'السعرات',
                        'Protein' => 'البروتين',
                        'Sodium' => 'الصوديوم',
                        'Water' => 'الماء',
                        _ => 'الوزن',
                      })}: ${item.current.toStringAsFixed(1)} ${item.unit} ($sign${item.change.toStringAsFixed(1)} ${tr('vs your baseline', 'مقابل خطك الأساسي')})';
                    }),
                    tr(
                      'Associations describe your records; they do not prove a cause.',
                      'العلاقات تصف سجلاتك ولا تثبت سببًا.',
                    ),
                  ]
                : [
                    tr(
                      'A personal comparison needs at least 7 earlier and 3 recent days for one metric.',
                      'تحتاج المقارنة الشخصية إلى 7 أيام سابقة و3 أيام حديثة على الأقل لمؤشر واحد.',
                    ),
                    tr(
                      'No population average is substituted for your missing data.',
                      'لن نستخدم متوسطات السكان بدلًا من بياناتك الناقصة.',
                    ),
                  ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
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
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          _SummaryCard(
            title: range.days == null
                ? tr('All-time summary', 'ملخص كل الوقت')
                : tr('${range.days}-day summary', 'ملخص ${range.days} يومًا'),
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
              tr(
                'Weight evidence: ${progress.sampleCount} measurements across ${progress.spanDays} days · ${progress.confidence.name} confidence',
                'دليل الوزن: ${progress.sampleCount} قياسًا خلال ${progress.spanDays} يومًا · ثقة ${switch (progress.confidence) {
                  ProgressConfidence.insufficient => 'غير كافية',
                  ProgressConfidence.low => 'منخفضة',
                  ProgressConfidence.medium => 'متوسطة',
                  ProgressConfidence.high => 'مرتفعة',
                }}',
              ),
              if (progress.monthlyDirectionKg != null)
                tr(
                  'Approximate monthly direction: ${progress.monthlyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(progress.monthlyDirectionKg!, system).toStringAsFixed(1)} $weightUnit',
                  'الاتجاه الشهري التقريبي: ${progress.monthlyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(progress.monthlyDirectionKg!, system).toStringAsFixed(1)} $weightUnit',
                ),
              if (progress.variabilityKg != null)
                tr(
                  'Variation around the direction: about ${UnitConverter.weightFromKg(progress.variabilityKg!, system).toStringAsFixed(2)} $weightUnit',
                  'التذبذب حول الاتجاه: نحو ${UnitConverter.weightFromKg(progress.variabilityKg!, system).toStringAsFixed(2)} $weightUnit',
                ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Text(
            tr('Weight over time', 'الوزن عبر الزمن'),
            style: PremiumDesignTokens.sectionHeading(context),
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
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Text(
            tr('Calories and protein by day', 'السعرات والبروتين حسب اليوم'),
            style: PremiumDesignTokens.sectionHeading(context),
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
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          Text(
            tr('Water adherence records', 'سجلات الالتزام بالماء'),
            style: PremiumDesignTokens.sectionHeading(context),
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
  Widget build(BuildContext context) => PremiumSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: PremiumDesignTokens.cardHeading(context)),
        const SizedBox(height: PremiumDesignTokens.spaceXs),
        ...lines.map(Text.new),
      ],
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
