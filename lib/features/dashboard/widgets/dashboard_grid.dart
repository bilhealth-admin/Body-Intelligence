import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../engine/bil_engine.dart';
import '../../../core/units/measurement_units.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/body_composition_engine.dart';
import '../../../engine/body_twin_engine.dart';
import '../../../engine/data_honesty_engine.dart';
import '../../../engine/daily_return_engine.dart';
import '../../../engine/intelligence_engine.dart';
import '../../../engine/one_best_action_engine.dart';
import '../../../engine/plan_engine.dart';
import '../../../engine/progress_analysis.dart';
import '../../../engine/what_changed_engine.dart';
import '../../../engine/recovery_engine.dart';
import '../../../engine/weekly_review_engine.dart';
import '../../ai_platform/domain/personal_health_ai.dart';
import '../../connected_health/widgets/connected_health_card.dart';
import '../../ai_platform/services/personal_health_ai_engine.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../engine/nutrient_evidence_engine.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../analytics/analytics_page.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../foods/providers/food_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../providers/dashboard_provider.dart';
import 'dashboard_carousel.dart';
import 'dashboard_loading_skeleton.dart';
import 'dashboard_meals_timeline.dart';
import 'dashboard_water_card.dart';
import 'nutrient_evidence_status_text.dart';
import 'daily_return_card.dart';
import 'premium_dashboard_benchmark.dart';
import 'personal_health_ai_panel.dart';

class DashboardGrid extends ConsumerWidget {
  const DashboardGrid({super.key, this.hero});

  final Widget? hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => arabic ? ar : en;
    final profileAsync = ref.watch(userProfileProvider);
    final weightsAsync = ref.watch(weightHistoryProvider);
    final mealsAsync = ref.watch(todayMealsProvider);
    final waterAsync = ref.watch(todayWaterProvider);
    final allMealsAsync = ref.watch(allMealsProvider);
    final allWaterAsync = ref.watch(allWaterProvider);
    final skippedWeightAsync = ref.watch(weightReminderSkippedTodayProvider);
    final contextAsync = ref.watch(todayLifeContextProvider);
    final allContextsAsync = ref.watch(insightLifeContextProvider);
    final memoriesAsync = ref.watch(decisionMemoriesProvider);
    final memoryEnabled =
        ref.watch(decisionMemoryEnabledProvider).value ?? true;
    final usualBreakfastCandidates =
        ref.watch(usualMealsProvider('breakfast')).value ?? const [];
    final usualBreakfast = usualBreakfastCandidates.firstOrNull;
    final recentBreakfast =
        (mealsAsync.value ?? const [])
            .where((entry) => entry.meal.type == 'breakfast')
            .toList()
          ..sort((a, b) => b.meal.date.compareTo(a.meal.date));
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    if ([
      profileAsync,
      weightsAsync,
      mealsAsync,
      waterAsync,
      allMealsAsync,
      allWaterAsync,
      skippedWeightAsync,
      contextAsync,
      allContextsAsync,
      memoriesAsync,
    ].any((value) => value.isLoading)) {
      return const DashboardLoadingSkeleton();
    }
    if (profileAsync.hasError ||
        weightsAsync.hasError ||
        mealsAsync.hasError ||
        waterAsync.hasError ||
        allMealsAsync.hasError ||
        allWaterAsync.hasError ||
        skippedWeightAsync.hasError ||
        contextAsync.hasError ||
        allContextsAsync.hasError ||
        memoriesAsync.hasError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.strings.text('Today could not read all local data'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.strings.text(
                  'No current insight is shown because it may be stale. Existing records remain in local storage; retry when storage is available.',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.invalidate(userProfileProvider);
                  ref.invalidate(weightHistoryProvider);
                  ref.invalidate(todayMealsProvider);
                  ref.invalidate(todayWaterProvider);
                  ref.invalidate(allMealsProvider);
                  ref.invalidate(allWaterProvider);
                  ref.invalidate(weightReminderSkippedTodayProvider);
                  ref.invalidate(todayLifeContextProvider);
                  ref.invalidate(insightLifeContextProvider);
                  ref.invalidate(decisionMemoriesProvider);
                },
                icon: const Icon(Icons.refresh),
                label: Text(context.strings.text('Try again')),
              ),
            ],
          ),
        ),
      );
    }
    final profile = profileAsync.value;
    if (profile == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            tr(
              'Complete your profile to calculate personalized targets.',
              'أكمل ملفك الشخصي لحساب أهدافك المخصصة.',
            ),
          ),
        ),
      );
    }
    final planAsync = ref.watch(planSettingProvider(profile.uuid));
    if (planAsync.isLoading) {
      return const DashboardLoadingSkeleton();
    }
    final weights = weightsAsync.value ?? const [];
    final meals = mealsAsync.value ?? const [];
    final waterRows = waterAsync.value ?? const [];
    final allMeals = allMealsAsync.value ?? const [];
    final allWater = allWaterAsync.value ?? const [];
    final allContexts = allContextsAsync.value ?? const [];
    final insightContexts = (contextAsync.value ?? const [])
        .where((entry) => entry.useInInsights)
        .toList();
    final lowRatings = <String, int>{};
    for (final memory in memoriesAsync.value ?? const []) {
      if ((memory.helpfulness ?? 5) <= 2) {
        lowRatings.update(
          memory.recommendationKey,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final suppressedActions = BestActionType.values
        .where((type) => (lowRatings[type.name] ?? 0) >= 2)
        .toSet();
    final skippedWeightToday = skippedWeightAsync.value ?? false;
    final items = meals.expand((meal) => meal.items).toList();
    final calories = items.fold<double>(0, (sum, item) => sum + item.calories);
    final protein = items.fold<double>(0, (sum, item) => sum + item.protein);
    final fats = items.fold<double>(0, (sum, item) => sum + item.fats);
    final sodium = items.fold<double>(0, (sum, item) => sum + item.sodium);
    NutrientEvidenceReport nutrientReport(
      TrackedNutrient nutrient,
      double Function(dynamic item) value,
    ) => NutrientEvidenceEngine.total([
      for (final item in items)
        NutrientObservation(
          value: value(item),
          available: NutrientEvidenceMask.contains(
            item.nutrientEvidenceMask,
            nutrient,
          ),
        ),
    ]);
    final fiberEvidence = nutrientReport(
      TrackedNutrient.fiber,
      (item) => item.fiber as double,
    );
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
    final bodyComposition = BodyCompositionEngine.calculate(
      gender: profile.gender,
      age: profile.age,
      heightCm: profile.height,
      currentWeightKg: currentWeight,
      neckCm: profile.neck,
      waistCm: profile.waist,
    );
    String compositionIssue(BodyCompositionIssue? issue) {
      return switch (issue) {
        BodyCompositionIssue.missingGender => tr(
          'Gender is not recorded',
          'الجنس غير مسجل',
        ),
        BodyCompositionIssue.unsupportedGender => tr(
          'Gender value is unsupported',
          'قيمة الجنس غير مدعومة',
        ),
        BodyCompositionIssue.missingAge => tr(
          'Age is not recorded',
          'العمر غير مسجل',
        ),
        BodyCompositionIssue.invalidAge => tr(
          'Age value is invalid',
          'قيمة العمر غير صالحة',
        ),
        BodyCompositionIssue.missingHeight => tr(
          'Height is not recorded',
          'الطول غير مسجل',
        ),
        BodyCompositionIssue.invalidHeight => tr(
          'Height value is invalid',
          'قيمة الطول غير صالحة',
        ),
        BodyCompositionIssue.missingWeight => tr(
          'Current weight is not recorded',
          'الوزن الحالي غير مسجل',
        ),
        BodyCompositionIssue.invalidWeight => tr(
          'Current weight is invalid',
          'الوزن الحالي غير صالح',
        ),
        BodyCompositionIssue.missingNeck => tr(
          'Neck circumference is not recorded',
          'محيط الرقبة غير مسجل',
        ),
        BodyCompositionIssue.invalidNeck => tr(
          'Neck circumference is invalid',
          'محيط الرقبة غير صالح',
        ),
        BodyCompositionIssue.missingWaist => tr(
          'Waist circumference is not recorded',
          'محيط الخصر غير مسجل',
        ),
        BodyCompositionIssue.invalidWaist => tr(
          'Waist circumference is invalid',
          'محيط الخصر غير صالح',
        ),
        BodyCompositionIssue.invalidBodyFat => tr(
          'Body fat estimate is invalid',
          'تقدير دهون الجسم غير صالح',
        ),
        null => tr('Unavailable', 'غير متاح'),
      };
    }

    String compositionValue(
      BodyCompositionMetric metric, {
      required String unit,
    }) {
      if (!metric.isAvailable) return compositionIssue(metric.issue);
      return '${metric.value!.toStringAsFixed(1)}$unit';
    }

    final plan = planAsync.value;
    final effectiveTargets = PlanEngine.effective(
      bil.targets,
      plan == null
          ? null
          : PlanOverrides(
              calories: plan.overrideCalories,
              protein: plan.overrideProtein,
              carbs: plan.overrideCarbs,
              fats: plan.overrideFats,
              fiber: plan.overrideFiber,
              water: plan.overrideWater,
            ),
    );
    final chronological = weights.reversed.map((row) => row.weight).toList();
    final mealDays = allMeals.map((row) => row.meal.dayKey).toSet();
    final waterDays = allWater.map((row) => row.dayKey).toSet();
    final weightDays = weights
        .map((row) => row.dayKey ?? dayKeyFor(row.date))
        .toSet();
    final observedDays = {...mealDays, ...waterDays, ...weightDays};
    final loggingStreak = consecutiveLoggingDays(observedDays, DateTime.now());
    final comparableWeightDays = weights
        .where((row) => row.measurementContext != 'differentConditions')
        .length;
    final intelligence = IntelligenceEngine.evaluate(
      calorieTarget: effectiveTargets.calories,
      proteinTarget: effectiveTargets.protein,
      waterTarget: effectiveTargets.water,
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
      weighedToday:
          weightDays.contains(dayKeyFor(DateTime.now())) || skippedWeightToday,
      loggingComplete: meals.isNotEmpty,
      protein: protein,
      proteinTarget: effectiveTargets.protein,
      waterMl: water,
      waterTarget: effectiveTargets.water,
      trackedDays: observedDays.length,
      suppressedTypes: suppressedActions,
    );
    final changed = WhatChangedEngine.compare(
      chronologicalWeights: chronological,
      comparableConditions:
          weights.length >= 2 &&
          weights[0].measurementContext == weights[1].measurementContext &&
          weights[0].measurementContext != 'differentConditions',
      contextTypes: insightContexts.map((entry) => entry.type).toList(),
    );
    DateTime? latestTrackedAt;
    void consider(DateTime value) {
      if (latestTrackedAt == null || value.isAfter(latestTrackedAt!)) {
        latestTrackedAt = value;
      }
    }

    for (final row in weights) {
      consider(row.date);
    }
    for (final row in allMeals) {
      consider(row.meal.date);
    }
    for (final row in allWater) {
      consider(row.occurredAt);
    }
    final recovery = RecoveryEngine.evaluate(
      now: DateTime.now(),
      lastTrackedAt: latestTrackedAt,
    );
    final dailyReturn = DailyReturnEngine.compose(
      hasWeight: weightDays.contains(dayKeyFor(DateTime.now())),
      hasMeals: meals.isNotEmpty,
      hasWater: waterRows.isNotEmpty,
      bestAction: bestAction,
      changed: changed,
      honesty: honesty,
      recovery: recovery,
    );
    final twin = BodyTwinEngine.simulate(
      calorieTarget: effectiveTargets.calories,
      tdee: bil.tdee.round(),
      weightDays: weightDays.length,
      nutritionDays: mealDays.length,
      observationDays: observedDays.length,
    );
    final weekCutoff = dayKeyFor(
      DateTime.now().subtract(const Duration(days: 6)),
    );
    final chronologicalWeights = weights.reversed.toList();
    final progressAnalysis = ProgressAnalysis.evaluate(
      samples: chronologicalWeights
          .map((row) => ProgressSample(date: row.date, weightKg: row.weight))
          .toList(),
      goalWeightKg: profile.targetWeight,
    );
    final recentJourneyWeights = chronologicalWeights.length > 30
        ? chronologicalWeights.sublist(chronologicalWeights.length - 30)
        : chronologicalWeights;
    final recentWeightDays = chronologicalWeights
        .where((row) => dayKeyFor(row.date).compareTo(weekCutoff) >= 0)
        .map((row) => dayKeyFor(row.date))
        .toSet();
    final recentMealDays = allMeals
        .where((row) => row.meal.dayKey.compareTo(weekCutoff) >= 0)
        .map((row) => row.meal.dayKey)
        .toSet();
    final recentWaterDays = allWater
        .where((row) => row.dayKey.compareTo(weekCutoff) >= 0)
        .map((row) => row.dayKey)
        .toSet();
    final recentContextDays = allContexts
        .where((row) => row.dayKey.compareTo(weekCutoff) >= 0)
        .map((row) => row.dayKey)
        .toSet();
    final weeklyReview = WeeklyReviewEngine.evaluate(
      weightDays: recentWeightDays.length,
      nutritionDays: recentMealDays.length,
      waterDays: recentWaterDays.length,
      contextDays: recentContextDays.length,
      weeklyWeightChangeKg: progressAnalysis.weeklyDirectionKg,
    );
    final localizedBestTitle = arabic
        ? switch (bestAction.type) {
            BestActionType.weighIn => 'سجّل وزن اليوم',
            BestActionType.completeLogging => 'أكمل تسجيل وجبة واحدة',
            BestActionType.protein => 'أضف مصدر بروتين مناسبًا اليوم',
            BestActionType.hydration => 'اشرب الماء تدريجيًا',
            BestActionType.holdPlan => 'حافظ على الخطة دون تغيير اليوم',
            BestActionType.none => 'لا حاجة لتغيير الخطة',
          }
        : bestAction.title;
    final localizedBestReason = arabic
        ? switch (bestAction.type) {
            BestActionType.weighIn =>
              'القياس اليومي المتقارب يحسن ثقة الاتجاه.',
            BestActionType.completeLogging =>
              'نقص تسجيل الوجبات يضعف تفسير بيانات المدخول.',
            BestActionType.protein =>
              'البروتين هو أكبر فجوة قابلة للتنفيذ اليوم.',
            BestActionType.hydration => 'الماء المسجل أقل بوضوح من هدف اليوم.',
            BestActionType.holdPlan =>
              'جمع ملاحظات أكثر اتساقًا أكثر أمانًا من التغيير المبكر.',
            BestActionType.none => 'الأولويات المسجلة اليوم مغطاة بصورة عامة.',
          }
        : bestAction.reason;
    final localizedChanged = arabic
        ? switch (changed.interpretation) {
            ChangeInterpretation.insufficient =>
              'نحتاج قياس وزن آخر في ظروف متقاربة لوصف التغير.',
            ChangeInterpretation.stable =>
              'الوزن مستقر بصورة عامة مقارنة بالقياس السابق.',
            ChangeInterpretation.likelyNoise =>
              'تغير الميزان، لكن قراءة واحدة لا تكفي لتغيير الخطة.',
            ChangeInterpretation.directional =>
              'سُجّل تغير محدود، ويظل الاتجاه عبر عدة أيام أكثر فائدة.',
          }
        : changed.summary;
    final primaryInsight = intelligence.insights.first;
    final localizedInsightTitle = arabic
        ? switch (primaryInsight.title) {
            'Protein below target' => 'البروتين أقل من الهدف',
            'Hydration opportunity' => 'فرصة لتحسين شرب الماء',
            'Possible plateau' => 'ثبات محتمل في الاتجاه',
            'Possible short-term water retention' =>
              'احتباس ماء قصير المدى محتمل',
            'Build your baseline' => 'ابنِ خطك الأساسي',
            _ => 'الأهداف اليومية متقاربة بصورة عامة',
          }
        : primaryInsight.title;

    Future<void> respondToAction(String response) async {
      if (!memoryEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Decision Memory is disabled. This response was not stored.',
                'ذاكرة القرارات معطلة. لم يُحفظ هذا الرد.',
              ),
            ),
          ),
        );
        return;
      }
      final repository = ref.read(decisionMemoryRepositoryProvider);
      final id = await repository.rememberAction(bestAction);
      await repository.respond(id, response);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response == 'done'
                  ? tr(
                      'Marked done. BIL will not assume an outcome without your later feedback.',
                      'تم وضع علامة «تم». لن يفترض BIL نتيجة دون ملاحظتك اللاحقة.',
                    )
                  : tr(
                      'Your response was saved locally and can be deleted from Decision Memory.',
                      'تم حفظ ردك محليًا ويمكن حذفه من ذاكرة القرارات.',
                    ),
            ),
          ),
        );
      }
    }

    Future<void> addWater(int amountMl) async {
      await ref
          .read(waterRepositoryProvider)
          .add(occurredAt: DateTime.now(), amountMl: amountMl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                '$amountMl ml added to today.',
                'تمت إضافة $amountMl مل إلى اليوم.',
              ),
            ),
          ),
        );
      }
    }

    Future<void> confirmAndRepeatBreakfast({
      required String titleEn,
      required String titleAr,
      required String contentEn,
      required String contentAr,
      required Future<void> Function() onConfirm,
    }) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr(titleEn, titleAr)),
          content: Text(tr(contentEn, contentAr)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('Add breakfast', 'إضافة الفطور')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await onConfirm();
      ref.invalidate(usualMealsProvider('breakfast'));
    }

    Future<void> repeatUsualBreakfast() async {
      final candidate = usualBreakfast;
      if (candidate == null) return;
      await confirmAndRepeatBreakfast(
        titleEn: 'Repeat usual breakfast?',
        titleAr: 'تكرار الفطور المعتاد؟',
        contentEn:
            'The same saved portions and nutrition snapshots will be added to today only after confirmation.',
        contentAr:
            'ستُضاف نفس الحصص ولقطات التغذية المحفوظة إلى اليوم بعد التأكيد فقط.',
        onConfirm: () => ref
            .read(mealRepositoryProvider)
            .repeatMeal(candidate: candidate, date: DateTime.now()),
      );
    }

    Future<void> repeatRecentBreakfast() async {
      final latestBreakfast = recentBreakfast.firstOrNull;
      if (latestBreakfast == null) return;
      await confirmAndRepeatBreakfast(
        titleEn: 'Repeat last breakfast?',
        titleAr: 'تكرار آخر فطور؟',
        contentEn:
            'Items and saved nutrition snapshots from your latest breakfast will be copied to today only after confirmation.',
        contentAr:
            'ستُنسخ العناصر ولقطات التغذية المحفوظة من آخر فطور إلى اليوم بعد التأكيد فقط.',
        onConfirm: () => ref
            .read(mealRepositoryProvider)
            .repeatHistoricalMeal(meal: latestBreakfast, date: DateTime.now()),
      );
    }

    final calorieByDay = <DateTime, double?>{};
    for (final meal in allMeals) {
      final day = DateTime(
        meal.meal.date.year,
        meal.meal.date.month,
        meal.meal.date.day,
      );
      final total = meal.items.fold<double>(
        0,
        (sum, item) => sum + item.calories,
      );
      calorieByDay.update(
        day,
        (value) => (value ?? 0) + total,
        ifAbsent: () => total,
      );
    }
    final healthAi = const PersonalHealthAiEngine().evaluate(
      asOf: DateTime.now(),
      weights: [
        for (final weight in weights)
          WeightObservation(
            at: weight.date,
            kg: weight.weight,
            comparability: weight.measurementContext == 'sameConditions'
                ? 1
                : 0.65,
          ),
      ],
      age: profile.age,
      heightCm: profile.height,
      gender: profile.gender,
      activityLevel: profile.activityLevel,
      dailyCalories: calorieByDay,
    );
    final personalHealthAiPanel = PersonalHealthAiPanel(
      snapshot: healthAi,
      arabic: arabic,
      todayHasMeals: meals.isNotEmpty,
      decisionCount: memoriesAsync.value?.length ?? 0,
      compact: MediaQuery.sizeOf(context).width < 600,
    );
    final progressSection = _DashboardPagedSection(
      title: tr("Today's Progress", 'تقدم اليوم'),
      subtitle: tr(
        'Your recorded nutrition and active daily references.',
        'تغذيتك المسجلة ومراجع يومك النشطة.',
      ),
      badge: loggingStreak >= 2
          ? _StreakBadge(days: loggingStreak, arabic: arabic)
          : null,
      pages: [
        _MetricGridPage(
          metrics: [
            _MetricData(
              Icons.local_fire_department_outlined,
              tr('Calories', 'السعرات'),
              meals.isEmpty
                  ? tr('Unavailable', 'غير متاح')
                  : calories.round().toString(),
              meals.isEmpty ? '' : (arabic ? 'سعرة' : 'kcal'),
              Colors.orange,
            ),
            _MetricData(
              Icons.fitness_center_outlined,
              tr('Protein', 'البروتين'),
              meals.isEmpty
                  ? tr('Unavailable', 'غير متاح')
                  : protein.round().toString(),
              meals.isEmpty ? '' : (arabic ? 'جم' : 'g'),
              Colors.green,
            ),
            _MetricData(
              Icons.opacity_outlined,
              tr('Fat', 'الدهون'),
              meals.isEmpty
                  ? tr('Unavailable', 'غير متاح')
                  : fats.round().toString(),
              meals.isEmpty ? '' : (arabic ? 'جم' : 'g'),
              Colors.purple,
            ),
            _MetricData(
              Icons.grass_outlined,
              tr('Fiber', 'الألياف'),
              fiberEvidence.total == null
                  ? tr('Unavailable', 'غير متاح')
                  : fiberEvidence.total!.round().toString(),
              fiberEvidence.total == null ? '' : (arabic ? 'جم' : 'g'),
              Colors.lightGreen,
            ),
          ],
        ),
        _MetricGridPage(
          metrics: [
            _MetricData(
              Icons.bolt_outlined,
              tr('Daily Requirement', 'الاحتياج اليومي'),
              bil.tdee.round().toString(),
              arabic ? 'سعرة/يوم' : 'kcal/day',
              Colors.deepOrangeAccent,
            ),
            _MetricData(
              Icons.monitor_weight_outlined,
              tr('Weight', 'الوزن'),
              UnitConverter.weightFromKg(
                currentWeight,
                system,
              ).toStringAsFixed(1),
              arabic
                  ? (system == MeasurementSystem.metric ? 'كجم' : 'رطل')
                  : UnitConverter.weightUnit(system),
              Colors.blue,
            ),
            _MetricData(
              Icons.accessibility_new_rounded,
              tr('Body mass index', 'مؤشر كتلة الجسم'),
              compositionValue(bodyComposition.bodyMassIndex, unit: ''),
              '',
              Colors.cyan,
            ),
            _MetricData(
              Icons.donut_large_rounded,
              tr('Body fat', 'نسبة دهون الجسم'),
              compositionValue(bodyComposition.bodyFatPercentage, unit: ''),
              bodyComposition.bodyFatPercentage.isAvailable ? '%' : '',
              Colors.pinkAccent,
            ),
          ],
        ),
      ],
    );
    final bodyProfile = _BodyProfileSnapshot(
      arabic: arabic,
      weight:
          '${UnitConverter.weightFromKg(currentWeight, system).toStringAsFixed(1)} ${arabic ? (system == MeasurementSystem.metric ? 'كجم' : 'رطل') : UnitConverter.weightUnit(system)}',
      height: '${profile.height.toStringAsFixed(1)} ${arabic ? 'سم' : 'cm'}',
      target:
          '${UnitConverter.weightFromKg(profile.targetWeight, system).toStringAsFixed(1)} ${arabic ? (system == MeasurementSystem.metric ? 'كجم' : 'رطل') : UnitConverter.weightUnit(system)}',
      calorieTarget:
          '${effectiveTargets.calories} ${arabic ? 'سعرة حرارية' : 'kcal'}',
      proteinTarget: '${effectiveTargets.protein} ${arabic ? 'جم' : 'g'}',
      waterTarget: '${effectiveTargets.water} ${arabic ? 'مل' : 'ml'}',
      dailyMetabolism:
          '${bil.tdee.round()} ${arabic ? 'سعرة حرارية/يوم' : 'kcal/day'}',
      neckCircumference: profile.neck == null
          ? tr('Neck circumference is not recorded', 'محيط الرقبة غير مسجل')
          : '${profile.neck!.toStringAsFixed(1)} ${arabic ? 'سم' : 'cm'}',
      waistCircumference: profile.waist == null
          ? tr('Waist circumference is not recorded', 'محيط الخصر غير مسجل')
          : '${profile.waist!.toStringAsFixed(1)} ${arabic ? 'سم' : 'cm'}',
      bodyMassIndex: compositionValue(bodyComposition.bodyMassIndex, unit: ''),
      bodyFatPercentage: compositionValue(
        bodyComposition.bodyFatPercentage,
        unit: '%',
      ),
      leanBodyMass: compositionValue(
        bodyComposition.leanBodyMassKg,
        unit: arabic ? ' كجم' : ' kg',
      ),
      onEditProfile: () => context.go('/profile-settings'),
      onEditPlan: () => context.go('/plan'),
    );
    final weightJourney = AnalyticsWeightJourneyCard(
      weights: recentJourneyWeights,
      system: system,
      rangeLabel: tr('Last 30 days', 'آخر 30 يومًا'),
      rangeDays: 30,
      weeklyRateKg: progressAnalysis.weeklyDirectionKg,
      progress: progressAnalysis,
    );
    final weeklyProgress = AnalyticsWeeklyProgressCard(
      weekly: weeklyReview,
      weeklyRateKg: progressAnalysis.weeklyDirectionKg,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumDashboardBenchmark(
          hero: hero,
          arabic: arabic,
          showRecommendation: bestAction.type == BestActionType.protein,
          actionTitle: localizedBestTitle,
          actionReason: localizedBestReason,
          actionEvidence: bestAction.evidence.isEmpty
              ? tr('Evidence is still forming', 'الأدلة لا تزال قيد التكوين')
              : arabic
              ? 'يستند إلى بياناتك المحلية المسجلة المتاحة.'
              : bestAction.evidence.join(' · '),
          confidence: switch (honesty.reliability) {
            DataReliability.insufficient => tr(
              'Insufficient evidence',
              'الأدلة غير كافية',
            ),
            DataReliability.emerging => tr('Emerging', 'قيد التكوين'),
            DataReliability.useful => tr('Useful', 'مفيدة'),
            DataReliability.strong => tr('Strong', 'قوية'),
          },
          onAction: dailyReturn.hasPrimaryAction
              ? () {
                  switch (bestAction.type) {
                    case BestActionType.weighIn:
                      context.go('/daily-check-in');
                    case BestActionType.completeLogging:
                    case BestActionType.protein:
                      context.go('/daily-log?meal=breakfast&focus=meal');
                    case BestActionType.hydration:
                      addWater(250);
                    case BestActionType.holdPlan:
                    case BestActionType.none:
                      break;
                  }
                }
              : null,
          dailyIntelligence: DailyReturnCard(
            report: dailyReturn,
            changedSummary: localizedChanged,
            actionTitle: localizedBestTitle,
            actionReason: localizedBestReason,
            missingEvidence: honesty.missing.isEmpty
                ? tr(
                    'No important evidence gap for today’s next decision.',
                    'لا توجد فجوة أدلة مهمة لقرار اليوم التالي.',
                  )
                : tr(
                    honesty.missing.first,
                    'تتحسن الثقة مع أيام محلية أكثر اكتمالًا واتساقًا.',
                  ),
            onPrimaryAction: null,
          ),
          progressSection: progressSection,
          personalHealthAi: personalHealthAiPanel,
          connectedHealth: ConnectedHealthCard(
            arabic: arabic,
            compact: MediaQuery.sizeOf(context).width < 600,
          ),
          bodyTwinSummary: twin.sufficient
              ? tr(
                  'A cautious planning direction is available; the range matters more than a single estimate.',
                  'يتوفر اتجاه تخطيط حذر؛ النطاق أهم من أي تقدير منفرد.',
                )
              : tr(
                  'BIL is still building a safe personal scenario.',
                  'لا يزال BIL يبني سيناريو شخصيًا آمنًا.',
                ),
          bodyTwinEvidence: twin.scenario == null
              ? tr(
                  twin.requiredData.join(' · '),
                  'نحتاج أيام ملاحظة ووزن وتغذية أكثر.',
                )
              : tr(
                  'Cautious range ${twin.scenario!.cautiousLowKg.toStringAsFixed(1)} to ${twin.scenario!.cautiousHighKg.toStringAsFixed(1)} kg/week',
                  'النطاق الحذر ${twin.scenario!.cautiousLowKg.toStringAsFixed(1)} إلى ${twin.scenario!.cautiousHighKg.toStringAsFixed(1)} كجم/أسبوع',
                ),
          nutritionSummary: meals.isEmpty
              ? tr(
                  'Nutrition interpretation is waiting for a meal observation.',
                  'ينتظر تفسير التغذية تسجيل وجبة.',
                )
              : effectiveTargets.protein - protein.round() >= 20
              ? tr(
                  'Protein is the clearest actionable nutrition gap today.',
                  'البروتين هو أوضح فجوة تغذية قابلة للتنفيذ اليوم.',
                )
              : tr(
                  'No nutrition change is more important than preserving complete evidence today.',
                  'لا يوجد تغيير غذائي أهم من الحفاظ على اكتمال الأدلة اليوم.',
                ),
          nutritionEvidence: meals.isEmpty
              ? tr('No meals recorded yet', 'لم تُسجّل وجبات بعد')
              : tr(
                  '${meals.length} meal records · ${protein.round()} g protein recorded',
                  '${meals.length} سجلات وجبات · ${protein.round()} جم بروتين مسجل',
                ),
          trendSummary: localizedChanged,
          trendEvidence: changed.evidence.isEmpty
              ? tr(
                  'Comparable observations are still forming',
                  'الملاحظات القابلة للمقارنة لا تزال قيد التكوين',
                )
              : changed.evidence.join(' · '),
          loggingItems: [
            DashboardLoggingItem(
              label: tr('Weight', 'الوزن'),
              recorded: dailyReturn.hasWeight,
            ),
            DashboardLoggingItem(
              label: tr('Meals', 'الوجبات'),
              recorded: dailyReturn.hasMeals,
            ),
            DashboardLoggingItem(
              label: tr('Water', 'الماء'),
              recorded: dailyReturn.hasWater,
            ),
          ],
          insightTitle: localizedInsightTitle,
          insightSummary: arabic
              ? 'يستند هذا الاستنتاج إلى بياناتك المحلية المسجلة فقط.'
              : '${primaryInsight.explanation} ${primaryInsight.suggestedAction}',
        ),
        Visibility(
          visible: false,
          maintainState: false,
          child: DashboardWaterCard(
            consumedMl: water,
            targetMl: effectiveTargets.water,
            onAdd: addWater,
          ),
        ),
        Visibility(
          visible: false,
          maintainState: false,
          child: DashboardMealsTimeline(
            meals: meals,
            onOpenMeal: (type) => context.go('/daily-log?meal=$type'),
            usualBreakfastAvailable: usualBreakfast != null,
            onRepeatBreakfast: repeatUsualBreakfast,
            recentBreakfastAvailable:
                usualBreakfast == null && recentBreakfast.isNotEmpty,
            onRepeatRecentBreakfast: repeatRecentBreakfast,
          ),
        ),
        Visibility(
          visible: false,
          maintainState: false,
          child: _DetailPanel(
            icon: Icons.task_alt_outlined,
            title: context.strings.text('One best action'),
            children: [
              FilledButton.tonal(
                onPressed: () => respondToAction('accepted'),
                child: Text(tr('Accept', 'قبول')),
              ),
              OutlinedButton(
                onPressed: () => respondToAction('done'),
                child: Text(tr('Done', 'تم')),
              ),
              TextButton(
                onPressed: () => respondToAction('notSuitable'),
                child: Text(tr('Not suitable today', 'غير مناسب اليوم')),
              ),
            ],
          ),
        ),
        const SizedBox(height: PremiumDesignTokens.spaceMd),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 1180) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  bodyProfile,
                  const SizedBox(height: 12),
                  Text(
                    tr('Analytics', 'التحليلات'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  weightJourney,
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  weeklyProgress,
                ],
              );
            }
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: weightJourney),
                  const SizedBox(width: PremiumDesignTokens.spaceMd),
                  Expanded(flex: 5, child: weeklyProgress),
                  const SizedBox(width: PremiumDesignTokens.spaceMd),
                  Expanded(flex: 9, child: bodyProfile),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DashboardPagedSection extends StatelessWidget {
  const _DashboardPagedSection({
    required this.title,
    required this.subtitle,
    required this.pages,
    this.badge,
  });

  final String title;
  final String subtitle;
  final List<Widget> pages;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final desktop = MediaQuery.sizeOf(context).width >= 900;
        final baseHeight = desktop
            ? 94.0
            : outerConstraints.maxWidth >= 560
            ? 214.0
            : 286.0;
        final heading = Row(
          children: [
            Expanded(
              child: _DashboardSectionHeading(title: title, subtitle: subtitle),
            ),
            if (badge != null) ...[
              const SizedBox(width: PremiumDesignTokens.spaceSm),
              badge!,
            ],
          ],
        );
        final carousel = DashboardCarousel(
          height: MediaQuery.textScalerOf(
            context,
          ).scale(baseHeight).clamp(baseHeight, baseHeight + 90),
          semanticLabel: title,
          pages: pages,
        );

        return PremiumSurface(
          dashboardGlass: true,
          padding: desktop
              ? const EdgeInsets.all(PremiumDesignTokens.spaceMd)
              : PremiumDesignTokens.cardPaddingLarge,
          child: desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 235, child: heading),
                    const SizedBox(width: PremiumDesignTokens.spaceMd),
                    Expanded(child: carousel),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: PremiumDesignTokens.spaceSm),
                    carousel,
                  ],
                ),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(this.icon, this.label, this.value, this.unit, this.accent);

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color accent;
}

class _MetricGridPage extends StatelessWidget {
  const _MetricGridPage({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wideScreen = MediaQuery.sizeOf(context).width >= 900;
        final columns = wideScreen
            ? metrics.length
            : constraints.maxWidth >= 560
            ? 3
            : 2;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: PremiumDesignTokens.spaceSm,
            mainAxisSpacing: PremiumDesignTokens.spaceSm,
            childAspectRatio: wideScreen ? 1.55 : 1.85,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _CompactMetricTile(
              icon: metric.icon,
              label: metric.label,
              value: metric.value,
              unit: metric.unit,
              accent: metric.accent,
            );
          },
        );
      },
    );
  }
}

class _BodyProfileSnapshot extends StatelessWidget {
  const _BodyProfileSnapshot({
    required this.arabic,
    required this.weight,
    required this.height,
    required this.target,
    required this.calorieTarget,
    required this.proteinTarget,
    required this.waterTarget,
    required this.dailyMetabolism,
    required this.neckCircumference,
    required this.waistCircumference,
    required this.bodyMassIndex,
    required this.bodyFatPercentage,
    required this.leanBodyMass,
    required this.onEditProfile,
    required this.onEditPlan,
  });

  final bool arabic;
  final String weight;
  final String height;
  final String target;
  final String calorieTarget;
  final String proteinTarget;
  final String waterTarget;
  final String dailyMetabolism;
  final String neckCircumference;
  final String waistCircumference;
  final String bodyMassIndex;
  final String bodyFatPercentage;
  final String leanBodyMass;
  final VoidCallback onEditProfile;
  final VoidCallback onEditPlan;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final values = [
      (tr('Current weight', 'الوزن الحالي'), weight),
      (tr('Height', 'الطول'), height),
      (tr('Target weight', 'الوزن المستهدف'), target),
      (tr('Daily energy plan', 'خطة الطاقة اليومية'), calorieTarget),
      (tr('Protein target', 'هدف البروتين'), proteinTarget),
      (tr('Water target', 'هدف الماء'), waterTarget),
      (tr('Daily metabolism', 'معدل الأيض اليومي'), dailyMetabolism),
      (tr('Neck circumference', 'محيط الرقبة'), neckCircumference),
      (tr('Waist circumference', 'محيط الخصر'), waistCircumference),
      (tr('Body mass index', 'مؤشر كتلة الجسم'), bodyMassIndex),
      (tr('Body fat percentage', 'نسبة دهون الجسم'), bodyFatPercentage),
      (tr('Lean body mass', 'الكتلة الخالية من الدهون'), leanBodyMass),
    ];

    return PremiumSurface(
      key: const Key('dashboard-body-profile'),
      dashboardGlass: true,
      padding: PremiumDesignTokens.cardPaddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline_rounded, color: scheme.primary),
              const SizedBox(width: PremiumDesignTokens.spaceSm),
              Expanded(
                child: _DashboardSectionHeading(
                  title: tr('Body profile & plan', 'ملف الجسم والخطة'),
                  subtitle: tr(
                    'Your current local baseline and active plan.',
                    'خط أساسك المحلي الحالي وخطتك النشطة.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceMd),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                final fixedDesktopGrid = screenWidth >= 1200;
                return Column(
                  children: [
                    SizedBox(
                      height: 142,
                      child: SvgPicture.asset(
                        'assets/images/dashboard/bil_body_profile.svg',
                        key: const Key('bil-body-profile-svg'),
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceSm),
                    SizedBox(
                      height: fixedDesktopGrid ? 192 : 184,
                      child: GridView.builder(
                        scrollDirection: fixedDesktopGrid
                            ? Axis.vertical
                            : Axis.horizontal,
                        physics: fixedDesktopGrid
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        padding: EdgeInsets.zero,
                        gridDelegate: fixedDesktopGrid
                            ? const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                childAspectRatio: 1.04,
                                crossAxisSpacing: PremiumDesignTokens.spaceXs,
                                mainAxisSpacing: PremiumDesignTokens.spaceXs,
                              )
                            : const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 176,
                                crossAxisSpacing: PremiumDesignTokens.spaceSm,
                                mainAxisSpacing: PremiumDesignTokens.spaceSm,
                              ),
                        itemCount: values.length,
                        itemBuilder: (context, index) => _BodyProfileValue(
                          label: values[index].$1,
                          value: values[index].$2,
                          compact: fixedDesktopGrid,
                        ),
                      ),
                    ),
                  ],
                );
              }
              final columns = constraints.maxWidth >= 900 ? 3 : 2;
              final gap = PremiumDesignTokens.spaceSm;
              final informationWidth =
                  constraints.maxWidth * .76 - PremiumDesignTokens.spaceMd;
              final width = (informationWidth - gap * (columns - 1)) / columns;
              final information = Wrap(
                spacing: gap,
                runSpacing: gap,
                children: values
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _BodyProfileValue(
                          label: item.$1,
                          value: item.$2,
                        ),
                      ),
                    )
                    .toList(),
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * .24,
                    height: 220,
                    child: SvgPicture.asset(
                      'assets/images/dashboard/bil_body_profile.svg',
                      key: const Key('bil-body-profile-svg'),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: PremiumDesignTokens.spaceMd),
                  Expanded(child: information),
                ],
              );
            },
          ),
          const SizedBox(height: PremiumDesignTokens.spaceMd),
          Wrap(
            spacing: PremiumDesignTokens.spaceSm,
            runSpacing: PremiumDesignTokens.spaceSm,
            children: [
              FilledButton.tonalIcon(
                onPressed: onEditProfile,
                icon: const Icon(Icons.edit_outlined),
                label: Text(tr('Edit profile', 'تعديل الملف')),
              ),
              OutlinedButton.icon(
                onPressed: onEditPlan,
                icon: const Icon(Icons.tune_rounded),
                label: Text(tr('Edit plan', 'تعديل الخطة')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BodyProfileValue extends StatelessWidget {
  const _BodyProfileValue({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: EdgeInsets.all(compact ? 2 : PremiumDesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusMd),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? Theme.of(context).textTheme.labelSmall
                        : Theme.of(context).textTheme.labelMedium)
                    ?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
          ),
          SizedBox(height: compact ? 1 : 4),
          Text(
            value,
            maxLines: compact ? 2 : 1,
            overflow: compact ? TextOverflow.visible : TextOverflow.ellipsis,
            style:
                (compact
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionHeading extends StatelessWidget {
  const _DashboardSectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      header: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: const Key('dashboard-today-summary-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: dark ? const Color(0xFFF4F8FB) : const Color(0xFF10283B),
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              shadows: dark
                  ? const [
                      Shadow(
                        color: Color(0x80000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            subtitle,
            key: const Key('dashboard-today-summary-subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: dark ? const Color(0xFFCAE0E8) : const Color(0xFF526B7C),
              fontWeight: FontWeight.w600,
              height: 1.4,
              shadows: dark
                  ? const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : const [],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetricTile extends StatelessWidget {
  const _CompactMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 56 : 88),
      padding: EdgeInsets.all(compact ? 2 : PremiumDesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .26),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusLg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: compact ? 14 : 19, color: accent),
              const SizedBox(width: PremiumDesignTokens.spaceXs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: compact
                      ? Theme.of(context).textTheme.labelSmall
                      : Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 1 : 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style:
                    (compact
                            ? Theme.of(context).textTheme.titleMedium
                            : Theme.of(context).textTheme.headlineSmall)
                        ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: PremiumDesignTokens.spaceXs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days, required this.arabic});

  final int days;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PremiumDesignTokens.spaceSm,
        vertical: PremiumDesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        arabic ? '$days أيام متتالية' : '$days day streak',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ignore: unused_element
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusLg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: PremiumDesignTokens.spaceSm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PremiumDesignTokens.spaceSm),
          ...children,
        ],
      ),
    );
  }
}

int consecutiveLoggingDays(Set<String> observedDays, DateTime today) {
  var streak = 0;
  var day = today;
  while (observedDays.contains(dayKeyFor(day))) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

// ignore: unused_element
class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.label,
    required this.evidence,
    required this.target,
    required this.unit,
    // ignore: unused_element_parameter
    this.upperLimit = false,
  });

  final String label;
  final NutrientEvidenceReport evidence;
  final double target;
  final String unit;
  final bool upperLimit;

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final consumed = evidence.total;
    if (consumed == null) {
      return _UnavailableNutrientRow(label: label);
    }
    final difference = target - consumed;
    final exceeded = difference < 0;
    final ratio = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);
    final needsAttention = upperLimit ? exceeded : consumed < target * 0.75;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            needsAttention ? Icons.info_outline : Icons.check_circle_outline,
            color: needsAttention
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$label · ${consumed.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit',
                ),
                if (evidence.state == NutrientEvidenceState.partial)
                  NutrientEvidenceStatusText(state: evidence.state),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: ratio),
                Text(
                  arabic
                      ? exceeded
                            ? '${difference.abs().toStringAsFixed(0)} $unit أعلى من الهدف المرجعي'
                            : '${difference.toStringAsFixed(0)} $unit متبقٍ'
                      : exceeded
                      ? '${difference.abs().toStringAsFixed(0)} $unit above the reference target'
                      : '${difference.toStringAsFixed(0)} $unit remaining',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _InformationalNutrientRow extends StatelessWidget {
  const _InformationalNutrientRow({
    required this.label,
    required this.evidence,
    required this.unit,
  });

  final String label;
  final NutrientEvidenceReport evidence;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (evidence.total == null) return _UnavailableNutrientRow(label: label);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline),
        title: Text(label),
        subtitle: evidence.state == NutrientEvidenceState.partial
            ? NutrientEvidenceStatusText(
                state: evidence.state,
                informational: true,
              )
            : Text(context.strings.text('No target; informational only')),
        trailing: Text('${evidence.total!.toStringAsFixed(0)} $unit'),
      ),
    );
  }
}

class _UnavailableNutrientRow extends StatelessWidget {
  const _UnavailableNutrientRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.help_outline),
        title: Text(label),
        subtitle: const NutrientEvidenceStatusText(
          state: NutrientEvidenceState.unavailable,
        ),
        trailing: const Text('—'),
      ),
    );
  }
}
