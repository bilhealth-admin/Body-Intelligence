import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../../data/database/date_keys.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/theme/premium_design_tokens.dart';
import '../../app/theme/premium_motion_tokens.dart';
import '../../core/units/measurement_units.dart';
import '../../engine/progress_analysis.dart';
import '../../engine/personal_baseline_engine.dart';
import '../../engine/recovery_engine.dart';
import '../../engine/weekly_review_engine.dart';
import '../../shared/widgets/actionable_error_state.dart';
import '../../shared/widgets/premium_chart_card.dart';
import '../../shared/widgets/premium_surface.dart';

import '../dashboard/providers/dashboard_provider.dart';
import '../daily_log/domain/daily_body_context_codec.dart';
import '../commerce/presentation/premium_nutrition_glass.dart';
import '../profile/providers/user_profile_provider.dart';
import '../life_context/providers/life_context_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'localized_confidence.dart';
import 'analytics_locale_copy.dart';
import 'widgets/analytics_range_selector.dart';
import 'widgets/analytics_weight_trend_chart.dart';

part 'widgets/analytics_page_primitives.dart';

/// Single clock boundary for Analytics range and recovery calculations.
///
/// Runtime behavior continues to use the device clock, while tests can freeze
/// the page to one instant so a render cannot drift across calendar days.
final analyticsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key, this.showSettingsBack = false});

  final bool showSettingsBack;

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  AnalyticsRange range = AnalyticsRange.thirtyDays;

  String _localizedProgressConfidence(
    BuildContext context,
    ProgressConfidence confidence,
  ) {
    return analyticsText(context, confidence.name, switch (confidence) {
      ProgressConfidence.insufficient => 'غير كافية',
      ProgressConfidence.low => 'منخفضة',
      ProgressConfidence.medium => 'متوسطة',
      ProgressConfidence.high => 'مرتفعة',
    });
  }

  String _rangeLabel(BuildContext context, AnalyticsRange selected) {
    return switch (selected) {
      AnalyticsRange.sevenDays => analyticsText(
        context,
        'Last 7 days',
        'آخر 7 أيام',
      ),
      AnalyticsRange.thirtyDays => analyticsText(
        context,
        'Last 30 days',
        'آخر 30 يومًا',
      ),
      AnalyticsRange.ninetyDays => analyticsText(
        context,
        'Last 90 days',
        'آخر 90 يومًا',
      ),
      AnalyticsRange.allTime => analyticsText(context, 'All time', 'كل الوقت'),
    };
  }

  PreferredSizeWidget? _settingsAppBar(BuildContext context) {
    if (!widget.showSettingsBack) return null;
    return AppBar(
      title: Text(analyticsText(context, 'Analytics', 'التحليلات')),
      actions: [
        IconButton(
          tooltip: analyticsText(
            context,
            'Create a share report',
            'إنشاء تقرير للمشاركة',
          ),
          onPressed: () => context.push('/share-studio'),
          icon: const Icon(Icons.ios_share_rounded),
        ),
      ],
      leading: IconButton(
        key: const Key('analytics-back-to-settings'),
        tooltip: analyticsText(
          context,
          'Back to settings',
          'العودة إلى الإعدادات',
        ),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/settings');
          }
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(analyticsClockProvider)();
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => analyticsText(context, en, ar);
    final weightsAsync = ref.watch(weightHistoryProvider);
    final mealsAsync = ref.watch(allMealsProvider);
    final waterAsync = ref.watch(allWaterProvider);
    final dailyLogsAsync = ref.watch(dashboardDailyLogsProvider);
    final contextsAsync = ref.watch(insightLifeContextProvider);
    final targetWeightKg = ref.watch(userProfileProvider).value?.targetWeight;
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final weightUnit = UnitConverter.weightUnit(system);
    if (weightsAsync.isLoading ||
        mealsAsync.isLoading ||
        waterAsync.isLoading ||
        dailyLogsAsync.isLoading ||
        contextsAsync.isLoading) {
      return Scaffold(
        appBar: _settingsAppBar(context),
        body: Semantics(
          label: tr('Loading analytics', 'جارٍ تحميل التحليلات'),
          liveRegion: true,
          child: ExcludeSemantics(
            child: ListView(
              padding: PremiumDesignTokens.screenPadding,
              children: const [
                _AnalyticsStateSkeletonBlock(height: 84),
                SizedBox(height: PremiumDesignTokens.spaceSm),
                _AnalyticsStateSkeletonBlock(height: 72),
                SizedBox(height: PremiumDesignTokens.spaceSm),
                _AnalyticsStateSkeletonBlock(height: 172),
                SizedBox(height: PremiumDesignTokens.spaceSm),
                _AnalyticsStateSkeletonBlock(height: 236),
                SizedBox(height: PremiumDesignTokens.spaceSm),
                _AnalyticsStateSkeletonBlock(height: 120),
              ],
            ),
          ),
        ),
      );
    }
    if (weightsAsync.hasError ||
        mealsAsync.hasError ||
        waterAsync.hasError ||
        dailyLogsAsync.hasError ||
        contextsAsync.hasError) {
      return Scaffold(
        appBar: _settingsAppBar(context),
        body: ActionableErrorState(
          title: tr(
            'Analytics data could not be loaded.',
            'تعذر تحميل بيانات التحليلات.',
          ),
          body: tr(
            'Some local records could not be read. Existing insights are hidden until local data is available again.',
            'تعذرت قراءة بعض السجلات المحلية. تم إخفاء الرؤى الحالية حتى تتوفر البيانات المحلية من جديد.',
          ),
          onRetry: () {
            ref.invalidate(weightHistoryProvider);
            ref.invalidate(allMealsProvider);
            ref.invalidate(allWaterProvider);
            ref.invalidate(dashboardDailyLogsProvider);
            ref.invalidate(insightLifeContextProvider);
          },
        ),
      );
    }
    final allWeights = (weightsAsync.value ?? const []).reversed.toList();
    final allMeals = mealsAsync.value ?? const [];
    final allWater = waterAsync.value ?? const [];
    final allDailyLogs = dailyLogsAsync.value ?? const <DailyLog>[];
    final allContexts = contextsAsync.value ?? const [];
    final start = range.days == null
        ? null
        : now.subtract(Duration(days: range.days! - 1));
    bool included(DateTime date) =>
        start == null || dayKeyFor(date).compareTo(dayKeyFor(start)) >= 0;
    final weights = allWeights.where((row) => included(row.date)).toList();
    final meals = allMeals.where((row) => included(row.meal.date)).toList();
    final water = allWater.where((row) => included(row.occurredAt)).toList();
    final contexts = allContexts
        .where((row) => included(row.occurredAt))
        .toList();
    final bodyContextLogs = allDailyLogs
        .where(
          (row) =>
              included(row.date) &&
              DailyBodyContextCodec.engineTypes(row.notes).isNotEmpty,
        )
        .toList(growable: false);
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
    final cutoffKey = dayKeyFor(now.subtract(const Duration(days: 6)));
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
    final recentContextDays = <String>{
      ...contexts
          .where((row) => row.dayKey.compareTo(cutoffKey) >= 0)
          .map((row) => row.dayKey),
      ...bodyContextLogs
          .where((row) => row.dayKey.compareTo(cutoffKey) >= 0)
          .map((row) => row.dayKey),
    };
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
      ...allDailyLogs
          .where(
            (row) => DailyBodyContextCodec.engineTypes(row.notes).isNotEmpty,
          )
          .map((row) => row.date),
    ]..sort();
    final recovery = RecoveryEngine.evaluate(
      now: now,
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
      appBar:
          _settingsAppBar(context) ??
          AppBar(
            title: Text(context.strings.text('Analytics')),
            actions: [
              IconButton(
                tooltip: tr('Create a share report', 'إنشاء تقرير للمشاركة'),
                onPressed: () => context.push('/share-studio'),
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
      body: AnimatedSwitcher(
        duration: PremiumMotionTokens.durationFor(
          context,
          PremiumMotionTokens.stateChangeDuration,
        ),
        switchInCurve: PremiumMotionTokens.stateChangeCurve,
        switchOutCurve: PremiumMotionTokens.stateChangeCurve,
        child: ListView(
          key: ValueKey<String>('analytics-range-${range.name}'),
          padding: PremiumDesignTokens.screenPadding.add(
            const EdgeInsets.only(bottom: 116),
          ),
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
            AnalyticsWeightJourneyCard(
              // The selected range is the source of truth for both the chart
              // and the evidence calculation.  Capping this at 30 made the
              // "All" range report the full sample count while displaying a
              // false start value from only the latest 30 measurements.
              weights: weights,
              system: system,
              rangeLabel: _rangeLabel(context, range),
              rangeDays: range.days,
              weeklyRateKg: rate,
              progress: progress,
              targetWeightKg: targetWeightKg,
            ),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
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
            PremiumNutritionGlass(
              key: const Key('analytics-personal-baseline-premium-glass'),
              child: _SummaryCard(
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
            ),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            AnalyticsWeeklyProgressCard(weekly: weekly, weeklyRateKg: rate),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            PremiumSurface(
              padding: PremiumDesignTokens.cardPaddingLarge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      tr(
                        'Evidence story for ${_rangeLabel(context, range)}',
                        'قصة الأدلة في ${_rangeLabel(context, range)}',
                      ),
                      style: PremiumDesignTokens.cardHeading(context),
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  Text(
                    tr(
                      'What changed, what supports it, and what remains uncertain.',
                      'ما الذي تغير، وما الذي يدعمه، وما الذي لا يزال غير محسوم.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceMd),
                  Wrap(
                    spacing: PremiumDesignTokens.spaceXs,
                    runSpacing: PremiumDesignTokens.spaceXs,
                    children: [
                      _EvidencePill(
                        label: tr('Tracked days', 'الأيام المسجلة'),
                        value: '$trackedDays',
                      ),
                      _EvidencePill(
                        label: tr('Weight points', 'نقاط الوزن'),
                        value: '${progress.sampleCount}',
                      ),
                      _EvidencePill(
                        label: tr('Evidence confidence', 'ثقة الأدلة'),
                        value: _localizedProgressConfidence(
                          context,
                          progress.confidence,
                        ),
                      ),
                      _EvidencePill(
                        label: tr('Selected range', 'النطاق المحدد'),
                        value: _rangeLabel(context, range),
                      ),
                    ],
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceMd),
                  Text(
                    tr('What changed', 'ما الذي تغير'),
                    style: PremiumDesignTokens.sectionHeading(context),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  Text(
                    rate == null
                        ? tr(
                            'Weight direction is not shown yet because this range does not have enough measured points.',
                            'لا يظهر اتجاه الوزن بعد لأن هذا النطاق لا يحتوي على نقاط قياس كافية.',
                          )
                        : tr(
                            'Smoothed weekly direction: ${rate >= 0 ? '+' : ''}${UnitConverter.weightFromKg(rate, system).toStringAsFixed(2)} $weightUnit/week.',
                            'الاتجاه الأسبوعي الممهّد: ${rate >= 0 ? '+' : ''}${UnitConverter.weightFromKg(rate, system).toStringAsFixed(2)} $weightUnit/أسبوع.',
                          ),
                  ),
                  if (progress.monthlyDirectionKg != null) ...[
                    const SizedBox(height: PremiumDesignTokens.spaceXs),
                    Text(
                      tr(
                        'Approximate monthly direction: ${progress.monthlyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(progress.monthlyDirectionKg!, system).toStringAsFixed(1)} $weightUnit.',
                        'الاتجاه الشهري التقريبي: ${progress.monthlyDirectionKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(progress.monthlyDirectionKg!, system).toStringAsFixed(1)} $weightUnit.',
                      ),
                    ),
                  ],
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  Text(
                    tr(
                      'What evidence supports this',
                      'ما الأدلة التي تدعم ذلك',
                    ),
                    style: PremiumDesignTokens.sectionHeading(context),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  Text(
                    tr(
                      '${progress.sampleCount} weight measurements across ${progress.spanDays} days and ${caloriesByDay.length} days with calculated meal totals.',
                      '${progress.sampleCount} قياس وزن خلال ${progress.spanDays} يومًا و${caloriesByDay.length} يومًا بإجماليات وجبات محسوبة.',
                    ),
                  ),
                  if (progress.variabilityKg != null) ...[
                    const SizedBox(height: PremiumDesignTokens.spaceXs),
                    Text(
                      tr(
                        'Observed variability around direction: about ${UnitConverter.weightFromKg(progress.variabilityKg!, system).toStringAsFixed(2)} $weightUnit.',
                        'التذبذب الملحوظ حول الاتجاه: نحو ${UnitConverter.weightFromKg(progress.variabilityKg!, system).toStringAsFixed(2)} $weightUnit.',
                      ),
                    ),
                  ],
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  Text(
                    tr('Uncertainty and confidence', 'عدم اليقين والثقة'),
                    style: PremiumDesignTokens.sectionHeading(context),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  Text(
                    tr(
                      'Current confidence: ${_localizedProgressConfidence(context, progress.confidence)}.',
                      'الثقة الحالية: ${_localizedProgressConfidence(context, progress.confidence)}.',
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  Text(
                    tr(
                      progress.confidence == ProgressConfidence.insufficient
                          ? 'The current evidence is not yet sufficient for a reliable trend claim.'
                          : progress.confidence == ProgressConfidence.low
                          ? 'The trend signal exists, but uncertainty remains high; avoid aggressive plan changes.'
                          : progress.confidence == ProgressConfidence.medium
                          ? 'Evidence supports a directional signal, but alternative explanations are still plausible.'
                          : 'Evidence is relatively consistent for this range, but confidence is not certainty.',
                      progress.confidence == ProgressConfidence.insufficient
                          ? 'الأدلة الحالية غير كافية بعد لادعاء اتجاه موثوق.'
                          : progress.confidence == ProgressConfidence.low
                          ? 'إشارة الاتجاه موجودة، لكن عدم اليقين ما يزال مرتفعًا؛ تجنّب تغييرات حادة في الخطة.'
                          : progress.confidence == ProgressConfidence.medium
                          ? 'الأدلة تدعم إشارة اتجاه، لكن تفسيرات بديلة ما تزال ممكنة.'
                          : 'الأدلة متسقة نسبيًا في هذا النطاق، لكن الثقة ليست يقينًا.',
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  Text(
                    tr(
                      'These records cannot on their own determine fat-versus-muscle change or prove cause and effect.',
                      'لا يمكن لهذه السجلات وحدها تحديد تغير الدهون مقابل العضلات أو إثبات علاقة سبب ونتيجة.',
                    ),
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  Text(
                    tr(
                      'If evidence is sparse, hold interpretation and add more consistent measurements first.',
                      'إذا كانت الأدلة متفرقة فالأفضل إيقاف التفسير وإضافة قياسات أكثر اتساقًا أولًا.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            Text(
              tr('Calories and protein by day', 'السعرات والبروتين حسب اليوم'),
              style: PremiumDesignTokens.sectionHeading(context),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('open-nutrition-analytics'),
                onPressed: () => context.push('/analytics/nutrition'),
                icon: const Icon(Icons.pie_chart_outline_rounded),
                label: Text(
                  tr('Open nutrition analytics', 'فتح تحليلات التغذية'),
                ),
              ),
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
              PremiumNutritionGlass(
                key: const Key('analytics-daily-nutrition-premium-glass'),
                showLabel: false,
                child: Column(
                  children: caloriesByDay.keys
                      .toList()
                      .reversed
                      .map(
                        (day) => ListTile(
                          title: Text(day),
                          subtitle: Text(
                            '${caloriesByDay[day]!.round()} ${tr('kcal', 'سعرة')} · ${proteinByDay[day]!.toStringAsFixed(1)} ${tr('g protein', 'غ بروتين')}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            Text(
              tr('Water adherence records', 'سجلات الالتزام بالماء'),
              style: PremiumDesignTokens.sectionHeading(context),
            ),
            ...waterByDay.keys.toList().reversed.map(
              (day) => _MetricBar(
                label: day,
                value: waterByDay[day]!.toDouble(),
                maximum: 3000,
                suffix: 'ml',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
