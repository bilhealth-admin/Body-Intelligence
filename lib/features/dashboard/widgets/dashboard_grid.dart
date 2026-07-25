import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../engine/bil_engine.dart';
import '../../../core/units/measurement_units.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/body_twin_engine.dart';
import '../../../engine/data_honesty_engine.dart';
import '../../../engine/daily_return_engine.dart';
import '../../../engine/intelligence_engine.dart';
import '../../../engine/one_best_action_engine.dart';
import '../../../engine/plan_engine.dart';
import '../../../engine/progress_analysis.dart';
import '../../../engine/what_changed_engine.dart';
import '../../../engine/recovery_engine.dart';
import '../../ai_platform/domain/personal_health_ai.dart';
import '../../ai_platform/services/personal_health_ai_engine.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../engine/nutrient_evidence_engine.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../../shared/widgets/premium_surface.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../history/history_page.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../foods/providers/food_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../providers/dashboard_provider.dart';
import 'confidence_ring.dart';
import 'dashboard_water_card.dart';
import 'dashboard_loading_skeleton.dart';
import 'dashboard_insights_surface.dart';
import 'weekly_progress_card.dart';
import 'dashboard_meals_timeline.dart';
import 'nutrient_evidence_status_text.dart';
import 'daily_return_card.dart';
import 'premium_dashboard_benchmark.dart';
import 'personal_health_ai_panel.dart';

class DashboardGrid extends ConsumerWidget {
  const DashboardGrid({super.key});

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
    final carbs = items.fold<double>(0, (sum, item) => sum + item.carbs);
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
    final sodiumEvidence = nutrientReport(
      TrackedNutrient.sodium,
      (item) => item.sodium as double,
    );
    final potassiumEvidence = nutrientReport(
      TrackedNutrient.potassium,
      (item) => item.potassium as double,
    );
    final calciumEvidence = nutrientReport(
      TrackedNutrient.calcium,
      (item) => item.calcium as double,
    );
    final magnesiumEvidence = nutrientReport(
      TrackedNutrient.magnesium,
      (item) => item.magnesium as double,
    );
    final sugarEvidence = nutrientReport(
      TrackedNutrient.sugar,
      (item) => item.sugar as double,
    );
    final water = waterRows.fold<int>(0, (sum, item) => sum + item.amountMl);
    final currentWeight = weights.firstOrNull?.weight ?? profile.currentWeight;
    final heightMeters = profile.height / 100;
    final bmi = heightMeters <= 0
        ? null
        : currentWeight / (heightMeters * heightMeters);
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
    final goalBaselineWeight =
        weights.lastOrNull?.weight ?? profile.currentWeight;
    final progressDenominator = (goalBaselineWeight - profile.targetWeight)
        .abs();
    final progress = progressDenominator == 0
        ? 1.0
        : (1 -
                  ((currentWeight - profile.targetWeight).abs() /
                      progressDenominator))
              .clamp(0.0, 1.0);
    final goalDate = intelligence.goalDate;
    final weekCutoff = dayKeyFor(
      DateTime.now().subtract(const Duration(days: 6)),
    );
    final weeklyWeights = weights
        .where(
          (row) =>
              (row.dayKey ?? dayKeyFor(row.date)).compareTo(weekCutoff) >= 0,
        )
        .toList();
    final weekStartWeight = weeklyWeights.isEmpty
        ? currentWeight
        : weeklyWeights.last.weight;
    final progressAnalysis = ProgressAnalysis.evaluate(
      samples: weights
          .map((row) => ProgressSample(date: row.date, weightKg: row.weight))
          .toList(),
      goalWeightKg: profile.targetWeight,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumDashboardBenchmark(
          arabic: arabic,
          showRecommendation: bestAction.type == BestActionType.protein,
          actionTitle: localizedBestTitle,
          actionReason: localizedBestReason,
          actionEvidence: bestAction.evidence.isEmpty
              ? tr('Evidence is still forming', 'الأدلة لا تزال قيد التكوين')
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
        ),
        const SizedBox(height: PremiumDesignTokens.spaceMd),
        PersonalHealthAiPanel(
          snapshot: healthAi,
          arabic: arabic,
          todayHasMeals: meals.isNotEmpty,
          decisionCount: memoriesAsync.value?.length ?? 0,
        ),
        const SizedBox(height: PremiumDesignTokens.spaceMd),
        Visibility(
          visible: false,
          maintainState: false,
          child: DailyReturnCard(
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
            onPrimaryAction: () {
              switch (bestAction.type) {
                case BestActionType.weighIn:
                  context.go('/daily-check-in');
                case BestActionType.completeLogging:
                case BestActionType.protein:
                  context.go('/daily-log');
                case BestActionType.hydration:
                  addWater(250);
                case BestActionType.holdPlan:
                case BestActionType.none:
                  break;
              }
            },
          ),
        ),
        const SizedBox(height: PremiumDesignTokens.spaceMd),
        Visibility(
          visible: true,
          maintainState: false,
          child: PremiumSurface(
            padding: PremiumDesignTokens.cardPaddingLarge,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth >= 860
                    ? (constraints.maxWidth -
                              (4 * PremiumDesignTokens.spaceSm)) /
                          5
                    : constraints.maxWidth >= 560
                    ? (constraints.maxWidth -
                              (2 * PremiumDesignTokens.spaceSm)) /
                          3
                    : (constraints.maxWidth - PremiumDesignTokens.spaceSm) / 2;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DashboardSectionHeading(
                                title: tr('Today progress', 'تقدم اليوم'),
                                subtitle: tr(
                                  'Recorded so far against your current plan. Missing observations stay unknown.',
                                  'المسجل حتى الآن مقابل خطتك الحالية. تبقى الملاحظات الناقصة غير معروفة.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (loggingStreak >= 2)
                          _StreakBadge(days: loggingStreak, arabic: arabic),
                      ],
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceMd),
                    Wrap(
                      spacing: PremiumDesignTokens.spaceSm,
                      runSpacing: PremiumDesignTokens.spaceSm,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _CompactMetricTile(
                            icon: Icons.monitor_weight_outlined,
                            label: tr('Weight', 'الوزن'),
                            value: UnitConverter.weightFromKg(
                              currentWeight,
                              system,
                            ).toStringAsFixed(1),
                            unit: UnitConverter.weightUnit(system),
                            accent: Colors.blue,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _CompactMetricTile(
                            icon: Icons.local_fire_department_outlined,
                            label: tr('Calories', 'السعرات'),
                            value: meals.isEmpty
                                ? tr('Unknown', 'غير معروف')
                                : calories.round().toString(),
                            unit: '/ ${effectiveTargets.calories}',
                            progress: effectiveTargets.calories <= 0
                                ? 0
                                : (calories / effectiveTargets.calories).clamp(
                                    0.0,
                                    1.0,
                                  ),
                            accent: Colors.orange,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _CompactMetricTile(
                            icon: Icons.fitness_center_outlined,
                            label: tr('Protein', 'البروتين'),
                            value: meals.isEmpty
                                ? tr('Unknown', 'غير معروف')
                                : protein.round().toString(),
                            unit: '/ ${effectiveTargets.protein} g',
                            progress: effectiveTargets.protein <= 0
                                ? 0
                                : (protein / effectiveTargets.protein).clamp(
                                    0.0,
                                    1.0,
                                  ),
                            accent: Colors.green,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _CompactMetricTile(
                            icon: Icons.grain_outlined,
                            label: tr('Carbs', 'الكربوهيدرات'),
                            value: meals.isEmpty
                                ? tr('Unknown', 'غير معروف')
                                : carbs.round().toString(),
                            unit: '/ ${effectiveTargets.carbs} g',
                            progress: effectiveTargets.carbs <= 0
                                ? 0
                                : (carbs / effectiveTargets.carbs).clamp(
                                    0.0,
                                    1.0,
                                  ),
                            accent: Colors.amber.shade800,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _CompactMetricTile(
                            icon: Icons.opacity_outlined,
                            label: tr('Fat', 'الدهون'),
                            value: meals.isEmpty
                                ? tr('Unknown', 'غير معروف')
                                : fats.round().toString(),
                            unit: '/ ${effectiveTargets.fats} g',
                            progress: effectiveTargets.fats <= 0
                                ? 0
                                : (fats / effectiveTargets.fats).clamp(
                                    0.0,
                                    1.0,
                                  ),
                            accent: Colors.purple,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _CompactMetricTile(
                            icon: Icons.water_drop_outlined,
                            label: tr('Water', 'الماء'),
                            value: waterRows.isEmpty
                                ? tr('Unknown', 'غير معروف')
                                : water.toString(),
                            unit: '/ ${effectiveTargets.water} ml',
                            progress:
                                waterRows.isEmpty || effectiveTargets.water <= 0
                                ? 0
                                : (water / effectiveTargets.water).clamp(
                                    0.0,
                                    1.0,
                                  ),
                            accent: Colors.cyan,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _CompactMetricTile(
                            icon: Icons.bolt_outlined,
                            label: tr('TDEE', 'الاحتياج اليومي'),
                            value: bil.tdee.round().toString(),
                            unit: 'kcal',
                            accent: Colors.deepOrangeAccent,
                          ),
                        ),
                        if (bmi != null)
                          SizedBox(
                            width: tileWidth,
                            child: _CompactMetricTile(
                              icon: Icons.accessibility_new_rounded,
                              label: tr('BMI', 'مؤشر كتلة الجسم'),
                              value: bmi.toStringAsFixed(1),
                              unit: '',
                              accent: Colors.indigoAccent,
                            ),
                          ),
                        SizedBox(
                          width: tileWidth,
                          child: _CompactMetricTile(
                            icon: Icons.person_outline_rounded,
                            label: tr('Current weight', 'الوزن الحالي'),
                            value: UnitConverter.weightFromKg(
                              profile.currentWeight,
                              system,
                            ).toStringAsFixed(1),
                            unit: UnitConverter.weightUnit(system),
                            accent: Colors.lightBlueAccent,
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _CompactMetricTile(
                            icon: Icons.flag_outlined,
                            label: tr('Goal progress', 'التقدم نحو الهدف'),
                            value: '${(progress * 100).round()}%',
                            unit: '',
                            progress: progress,
                            accent: Colors.tealAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: PremiumDesignTokens.spaceMd),
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
        const SizedBox(height: PremiumDesignTokens.spaceMd),
        _BodyProfileSnapshot(
          arabic: arabic,
          weight:
              '${UnitConverter.weightFromKg(currentWeight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
          height: '${profile.height.toStringAsFixed(1)} cm',
          target:
              '${UnitConverter.weightFromKg(profile.targetWeight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
          calorieTarget: '${effectiveTargets.calories} kcal',
          proteinTarget: '${effectiveTargets.protein} g',
          waterTarget: '${effectiveTargets.water} ml',
          onEditProfile: () => context.go('/profile-settings'),
          onEditPlan: () => context.go('/plan'),
        ),
        const SizedBox(height: PremiumDesignTokens.spaceMd),
        PremiumSurface(
          padding: EdgeInsets.zero,
          child: DashboardInsightsSurface(
            initiallyExpanded: true,
            collapsible: false,
            leading: const Icon(Icons.insights_outlined),
            title: Text(
              tr(
                'Insights, progress and evidence',
                'التحليلات والتقدم والأدلة',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              tr(
                'What BIL knows, why it matters, and how strong the evidence is.',
                'ما يعرفه BIL، ولماذا يهم، ومدى قوة الأدلة.',
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              PremiumDesignTokens.spaceMd,
              0,
              PremiumDesignTokens.spaceMd,
              PremiumDesignTokens.spaceMd,
            ),
            children: [
              const Divider(),
              _DetailPanel(
                icon: Icons.show_chart_rounded,
                title: tr('Weight over time', 'الوزن عبر الزمن'),
                children: [
                  WeightTrendChart(
                    weights: weights
                        .take(30)
                        .toList()
                        .reversed
                        .map((row) => row.weight)
                        .toList(),
                    variability: progressAnalysis.variabilityKg,
                    semanticsLabel: tr(
                      'Recorded weight trend over time',
                      'اتجاه الوزن المسجل عبر الزمن',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              WeeklyProgressCard(
                start: UnitConverter.weightFromKg(weekStartWeight, system),
                today: UnitConverter.weightFromKg(currentWeight, system),
                goal: UnitConverter.weightFromKg(profile.targetWeight, system),
                unit: UnitConverter.weightUnit(system),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              _DetailPanel(
                icon: Icons.flag_outlined,
                title:
                    '${tr('Goal progress', 'التقدم نحو الهدف')} ${(progress * 100).round()}%',
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: PremiumDesignTokens.spaceSm),
                  Text(
                    arabic
                        ? 'الاحتياج اليومي المقدر ${bil.tdee.round()} سعرة · هدف السعرات ${effectiveTargets.calories}'
                        : 'Estimated TDEE ${bil.tdee.round()} kcal · planned ${goalType == 'lose'
                              ? 'deficit'
                              : goalType == 'gain'
                              ? 'surplus'
                              : 'maintenance'} ${effectiveTargets.calories - bil.tdee.round()} kcal',
                  ),
                  const SizedBox(height: PremiumDesignTokens.spaceXs),
                  Text(
                    goalDate == null
                        ? tr(
                            'Goal date: more consistent weight data needed',
                            'تاريخ الهدف: نحتاج بيانات وزن أكثر اتساقًا',
                          )
                        : '${tr('Estimated goal date', 'تاريخ الهدف المقدر')}: ${goalDate.year}-${goalDate.month.toString().padLeft(2, '0')}-${goalDate.day.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              _DetailPanel(
                icon: Icons.auto_awesome_outlined,
                title: localizedInsightTitle,
                children: [
                  Text(
                    arabic
                        ? 'يستند هذا الاستنتاج إلى بياناتك المحلية المسجلة فقط. اجمع أيامًا إضافية قبل تغيير الخطة.'
                        : '${primaryInsight.explanation}\n${primaryInsight.suggestedAction}',
                  ),
                ],
              ),
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              Visibility(
                visible: false,
                maintainState: false,
                child: _DetailPanel(
                  icon: Icons.task_alt_outlined,
                  title: context.strings.text('One best action'),
                  children: [
                    Text(
                      localizedBestTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: PremiumDesignTokens.spaceXs),
                    Text(localizedBestReason),
                    const SizedBox(height: PremiumDesignTokens.spaceSm),
                    Wrap(
                      spacing: PremiumDesignTokens.spaceSm,
                      runSpacing: PremiumDesignTokens.spaceSm,
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
                          child: Text(
                            tr('Not suitable today', 'غير مناسب اليوم'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PremiumDesignTokens.spaceMd),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: ConfidenceRing(
                  score: honesty.score,
                  reliability: honesty.reliability,
                ),
                title: Text(context.strings.text('Data honesty')),
                subtitle: Text(
                  arabic
                      ? 'موثوقية ${switch (honesty.reliability) {
                          DataReliability.insufficient => 'غير كافية',
                          DataReliability.emerging => 'قيد التكوين',
                          DataReliability.useful => 'مفيدة',
                          DataReliability.strong => 'قوية',
                        }}'
                      : '${honesty.reliability.name} reliability',
                ),
                children: [
                  if (arabic)
                    Text(
                      'أيام الوزن: ${weightDays.length} · أيام التغذية: ${mealDays.length} · أيام الماء: ${waterDays.length}.',
                    )
                  else ...[
                    if (honesty.strengths.isNotEmpty)
                      Text('Evidence: ${honesty.strengths.join(' · ')}'),
                    if (honesty.missing.isNotEmpty)
                      Text(
                        'Improve confidence: ${honesty.missing.join(' · ')}',
                      ),
                  ],
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(context.strings.text('What changed today?')),
                subtitle: Text(localizedChanged),
                children: [
                  if (changed.evidence.isNotEmpty && !arabic)
                    Text('Evidence: ${changed.evidence.join(' · ')}'),
                  Text(
                    arabic
                        ? 'تفسيرات بديلة محتملة: الماء والجليكوجين ومحتوى الجهاز الهضمي وتوقيت القياس ونقص التسجيل. لا يُعد أي منها تشخيصًا.'
                        : 'Other explanations: ${changed.alternatives.join(' · ')}',
                  ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(context.strings.text('Body Twin')),
                subtitle: Text(
                  arabic
                      ? twin.sufficient
                            ? 'سيناريو حذر متاح من أدلتك المحلية'
                            : 'يتعلم بأمان · نحتاج بيانات أكثر'
                      : twin.sufficient
                      ? 'Cautious scenario available from your local evidence'
                      : 'Learning safely · ${twin.requiredData.join(' · ')}',
                ),
                children: [
                  if (twin.scenario != null) ...[
                    Text(
                      '${tr('Expected planning direction', 'اتجاه التخطيط المتوقع')}: ${twin.scenario!.expectedWeeklyKg.toStringAsFixed(2)} ${tr('kg/week', 'كجم/أسبوع')}',
                    ),
                    Text(
                      '${tr('Cautious range', 'النطاق الحذر')}: ${twin.scenario!.cautiousLowKg.toStringAsFixed(2)} ${tr('to', 'إلى')} ${twin.scenario!.cautiousHighKg.toStringAsFixed(2)} ${tr('kg/week', 'كجم/أسبوع')}',
                    ),
                  ],
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  tr('Available nutrient evidence', 'أدلة العناصر المتاحة'),
                ),
                subtitle: Text(
                  tr(
                    'Unavailable nutrients are never shown as zero.',
                    'لا تظهر العناصر غير المتاحة على أنها صفر.',
                  ),
                ),
                children: [
                  _TargetRow(
                    label: tr('Fiber', 'الألياف'),
                    evidence: fiberEvidence,
                    target: effectiveTargets.fiber.toDouble(),
                    unit: 'g',
                  ),
                  _TargetRow(
                    label: tr('Sodium', 'الصوديوم'),
                    evidence: sodiumEvidence,
                    target: effectiveTargets.sodium.toDouble(),
                    unit: 'mg',
                    upperLimit: true,
                  ),
                  _TargetRow(
                    label: tr('Potassium', 'البوتاسيوم'),
                    evidence: potassiumEvidence,
                    target: effectiveTargets.potassium.toDouble(),
                    unit: 'mg',
                  ),
                  _InformationalNutrientRow(
                    label: tr('Calcium', 'الكالسيوم'),
                    evidence: calciumEvidence,
                    unit: 'mg',
                  ),
                  _InformationalNutrientRow(
                    label: tr('Magnesium', 'المغنيسيوم'),
                    evidence: magnesiumEvidence,
                    unit: 'mg',
                  ),
                  _InformationalNutrientRow(
                    label: tr('Sugar', 'السكر'),
                    evidence: sugarEvidence,
                    unit: 'g',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
  final VoidCallback onEditProfile;
  final VoidCallback onEditPlan;

  String tr(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = [
      (tr('Current weight', 'الوزن الحالي'), weight),
      (tr('Height', 'الطول'), height),
      (tr('Target weight', 'الوزن المستهدف'), target),
      (tr('Daily energy plan', 'خطة الطاقة اليومية'), calorieTarget),
      (tr('Protein target', 'هدف البروتين'), proteinTarget),
      (tr('Water target', 'هدف الماء'), waterTarget),
    ];

    return PremiumSurface(
      key: const Key('dashboard-body-profile'),
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
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 520
                  ? 2
                  : 1;
              final gap = PremiumDesignTokens.spaceSm;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: values
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(
                            PremiumDesignTokens.spaceSm,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: .46,
                            ),
                            borderRadius: BorderRadius.circular(
                              PremiumDesignTokens.radiusMd,
                            ),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: .72,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.$2,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
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

class _DashboardSectionHeading extends StatelessWidget {
  const _DashboardSectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            key: const Key('dashboard-today-summary-title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFFF4F8FB),
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              shadows: const [
                Shadow(
                  color: Color(0x80000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: PremiumDesignTokens.spaceXs),
          Text(
            subtitle,
            key: const Key('dashboard-today-summary-subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFCAE0E8),
              fontWeight: FontWeight.w600,
              height: 1.4,
              shadows: const [
                Shadow(
                  color: Color(0x66000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
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
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color accent;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(PremiumDesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(PremiumDesignTokens.radiusLg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: accent),
              const SizedBox(width: PremiumDesignTokens.spaceXs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
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
          if (progress != null) ...[
            const SizedBox(height: PremiumDesignTokens.spaceSm),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                color: accent,
                backgroundColor: accent.withValues(alpha: .14),
              ),
            ),
          ],
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

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.label,
    required this.evidence,
    required this.target,
    required this.unit,
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
