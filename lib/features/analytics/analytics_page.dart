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
import '../profile/providers/user_profile_provider.dart';
import '../life_context/providers/life_context_provider.dart';
import '../weight/providers/weight_provider.dart';
import 'widgets/analytics_range_selector.dart';
import 'localized_confidence.dart';

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
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    if (!arabic) return confidence.name;
    return switch (confidence) {
      ProgressConfidence.insufficient => 'غير كافية',
      ProgressConfidence.low => 'منخفضة',
      ProgressConfidence.medium => 'متوسطة',
      ProgressConfidence.high => 'مرتفعة',
    };
  }

  String _rangeLabel(BuildContext context, AnalyticsRange selected) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return switch (selected) {
      AnalyticsRange.sevenDays => arabic ? 'آخر 7 أيام' : 'Last 7 days',
      AnalyticsRange.thirtyDays => arabic ? 'آخر 30 يومًا' : 'Last 30 days',
      AnalyticsRange.ninetyDays => arabic ? 'آخر 90 يومًا' : 'Last 90 days',
      AnalyticsRange.allTime => arabic ? 'كل الوقت' : 'All time',
    };
  }

  PreferredSizeWidget? _settingsAppBar(BuildContext context) {
    if (!widget.showSettingsBack) return null;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return AppBar(
      title: Text(arabic ? 'التحليلات' : 'Analytics'),
      leading: IconButton(
        key: const Key('analytics-back-to-settings'),
        tooltip: arabic ? 'العودة إلى الإعدادات' : 'Back to settings',
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
      body: AnimatedSwitcher(
        duration: PremiumMotionTokens.durationFor(
          context,
          PremiumMotionTokens.stateChangeDuration,
        ),
        switchInCurve: PremiumMotionTokens.stateChangeCurve,
        switchOutCurve: PremiumMotionTokens.stateChangeCurve,
        child: ListView(
          key: ValueKey<String>('analytics-range-${range.name}'),
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
            AnalyticsWeightJourneyCard(
              weights: recentWeights,
              system: system,
              rangeLabel: _rangeLabel(context, range),
              rangeDays: range.days,
              weeklyRateKg: rate,
              progress: progress,
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
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PremiumSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: rtl ? TextAlign.right : TextAlign.left,
            style: PremiumDesignTokens.cardHeading(context),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          ...lines.map(
            (line) =>
                Text(line, textAlign: rtl ? TextAlign.right : TextAlign.left),
          ),
        ],
      ),
    );
  }
}

class AnalyticsWeeklyProgressCard extends StatelessWidget {
  const AnalyticsWeeklyProgressCard({
    super.key,
    required this.weekly,
    required this.weeklyRateKg,
  });

  final WeeklyReview weekly;
  final double? weeklyRateKg;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => arabic ? ar : en;
    return _SummaryCard(
      title: tr('Weekly review', 'المراجعة الأسبوعية'),
      lines: [
        tr(
          '${weekly.trackedDays} of 7 days with at least one core record',
          '${weekly.trackedDays} من 7 أيام بها سجل أساسي واحد على الأقل',
        ),
        if (arabic)
          weeklyRateKg == null
              ? 'لا توجد أدلة وزن متقاربة كافية لاتجاه أسبوعي.'
              : 'الاتجاه الأسبوعي الممهّد: ${weeklyRateKg! >= 0 ? '+' : ''}${weeklyRateKg!.toStringAsFixed(2)} كجم. لا يحدد هذا تغير الدهون أو العضلات.'
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
                if (weekly.waterDays < 5) 'تحسّن أيام الترطيب فهم الالتزام',
              ]
            : weekly.missingData),
      ],
    );
  }
}

class AnalyticsWeightJourneyCard extends StatelessWidget {
  const AnalyticsWeightJourneyCard({
    super.key,
    required this.weights,
    required this.system,
    required this.rangeLabel,
    required this.rangeDays,
    required this.weeklyRateKg,
    required this.progress,
  });

  final List<WeightEntry> weights;
  final MeasurementSystem system;
  final String rangeLabel;
  final int? rangeDays;
  final double? weeklyRateKg;
  final ProgressAnalysis progress;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => arabic ? ar : en;
    final unit = UnitConverter.weightUnit(system);
    final confidence = arabic
        ? switch (progress.confidence) {
            ProgressConfidence.insufficient => 'غير كافية',
            ProgressConfidence.low => 'منخفضة',
            ProgressConfidence.medium => 'متوسطة',
            ProgressConfidence.high => 'مرتفعة',
          }
        : progress.confidence.name;
    return PremiumChartCard(
      semanticLabel: tr(
        'Weight chart with evidence explanation',
        'مخطط الوزن مع شرح الأدلة',
      ),
      title: tr('Weight over time', 'الوزن عبر الزمن'),
      subtitle: rangeDays == null
          ? tr(
              'Measured local check-ins across all recorded time.',
              'قياسات تسجيل محلية عبر كامل الفترة المسجلة.',
            )
          : tr(
              'Measured local check-ins across the selected $rangeDays-day range.',
              'قياسات تسجيل محلية عبر نطاق $rangeDays يومًا المحدد.',
            ),
      chart: _WeightTrendChart(
        weights: weights,
        system: system,
        rangeLabel: rangeLabel,
      ),
      explanation: [
        tr(
          'Trend direction: ${weeklyRateKg == null ? 'insufficient evidence' : '${weeklyRateKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(weeklyRateKg!, system).toStringAsFixed(2)} $unit/week (smoothed)'}',
          'اتجاه المسار: ${weeklyRateKg == null ? 'أدلة غير كافية' : '${weeklyRateKg! >= 0 ? '+' : ''}${UnitConverter.weightFromKg(weeklyRateKg!, system).toStringAsFixed(2)} $unit/أسبوع (ممهّد)'}',
        ),
        tr(
          'Evidence sufficiency: ${progress.sampleCount} measurements across ${progress.spanDays} days ($confidence).',
          'كفاية الأدلة: ${progress.sampleCount} قياسًا خلال ${progress.spanDays} يومًا (ثقة $confidence).',
        ),
        tr(
          'This chart reflects measured weight only and cannot safely conclude fat or muscle change on its own.',
          'يعرض هذا المخطط الوزن المقاس فقط ولا يمكنه وحده استنتاج تغير الدهون أو العضلات بشكل آمن.',
        ),
      ],
      footer: weights.isEmpty
          ? Text(
              tr(
                'Add weight entries to unlock trend interpretation.',
                'أضف قياسات وزن لبدء تفسير الاتجاه.',
              ),
            )
          : null,
    );
  }
}

class _WeightTrendChart extends StatelessWidget {
  const _WeightTrendChart({
    required this.weights,
    required this.system,
    required this.rangeLabel,
  });

  final List<WeightEntry> weights;
  final MeasurementSystem system;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    if (weights.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            context.strings.text('No local weight measurements in this range.'),
          ),
        ),
      );
    }

    final converted = weights
        .map((entry) => UnitConverter.weightFromKg(entry.weight, system))
        .toList();
    final minValue = converted.reduce((a, b) => a < b ? a : b);
    final maxValue = converted.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.01
        ? 1.0
        : (maxValue - minValue);
    final unit = UnitConverter.weightUnit(system);
    final firstValue = converted.first;
    final lastValue = converted.last;
    final delta = lastValue - firstValue;

    return SizedBox(
      height: 236,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35),
              Theme.of(context).colorScheme.surfaceContainerLow,
            ],
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PremiumDesignTokens.spaceMd,
            PremiumDesignTokens.spaceSm,
            PremiumDesignTokens.spaceMd,
            PremiumDesignTokens.spaceSm,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ChartMetricChip(
                      label: arabic ? 'البداية' : 'Start',
                      value: '${firstValue.toStringAsFixed(1)} $unit',
                    ),
                  ),
                  const SizedBox(width: PremiumDesignTokens.spaceXs),
                  Expanded(
                    child: _ChartMetricChip(
                      label: arabic ? 'الحالي' : 'Current',
                      value: '${lastValue.toStringAsFixed(1)} $unit',
                      emphasize: true,
                    ),
                  ),
                  const SizedBox(width: PremiumDesignTokens.spaceXs),
                  Expanded(
                    child: _ChartMetricChip(
                      label: arabic ? 'تغير النطاق' : 'Range change',
                      value:
                          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} $unit',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PremiumDesignTokens.spaceSm),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ChartAxisLabels(
                      top: maxValue,
                      middle: minValue + (span / 2),
                      bottom: minValue,
                      unit: unit,
                    ),
                    const SizedBox(width: PremiumDesignTokens.spaceXs),
                    Expanded(
                      child: CustomPaint(
                        painter: _WeightLinePainter(
                          values: converted,
                          minValue: minValue,
                          span: span,
                          lineColor: Theme.of(context).colorScheme.primary,
                          pointColor: Theme.of(context).colorScheme.tertiary,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.bottomEnd,
                          child: Semantics(
                            label: context.strings.text(
                              'Current measured point',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: PremiumDesignTokens.spaceXs,
                                vertical: PremiumDesignTokens.spaceXs,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  PremiumDesignTokens.radiusMd,
                                ),
                              ),
                              child: Text(
                                '${lastValue.toStringAsFixed(1)} $unit',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceXs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  rangeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightLinePainter extends CustomPainter {
  _WeightLinePainter({
    required this.values,
    required this.minValue,
    required this.span,
    required this.lineColor,
    required this.pointColor,
  });

  final List<double> values;
  final double minValue;
  final double span;
  final Color lineColor;
  final Color pointColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : (index / (values.length - 1)) * size.width;
      final normalized = (values[index] - minValue) / span;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);

    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : (index / (values.length - 1)) * size.width;
      final normalized = (values[index] - minValue) / span;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      final point = Offset(x, y);

      canvas.drawCircle(
        point,
        6,
        Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        7.5,
        Paint()
          ..color = Colors.white.withValues(alpha: .92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        point,
        index == values.length - 1 ? 12 : 9,
        Paint()
          ..color = pointColor.withValues(
            alpha: index == values.length - 1 ? .22 : .10,
          )
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeightLinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.minValue != minValue ||
        oldDelegate.span != span ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.pointColor != pointColor;
  }
}

class _ChartMetricChip extends StatelessWidget {
  const _ChartMetricChip({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PremiumDesignTokens.spaceXs,
        vertical: PremiumDesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: emphasize
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ChartAxisLabels extends StatelessWidget {
  const _ChartAxisLabels({
    required this.top,
    required this.middle,
    required this.bottom,
    required this.unit,
  });

  final double top;
  final double middle;
  final double bottom;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      width: 54,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${top.toStringAsFixed(1)} $unit', style: textStyle),
          Text('${middle.toStringAsFixed(1)} $unit', style: textStyle),
          Text('${bottom.toStringAsFixed(1)} $unit', style: textStyle),
        ],
      ),
    );
  }
}

class _EvidencePill extends StatelessWidget {
  const _EvidencePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PremiumDesignTokens.spaceSm,
          vertical: PremiumDesignTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsStateSkeletonBlock extends StatelessWidget {
  const _AnalyticsStateSkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusLg),
      ),
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: FractionallySizedBox(
          widthFactor: 0.45,
          child: Container(
            height: PremiumDesignTokens.spaceSm,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
            ),
          ),
        ),
      ),
    );
  }
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
