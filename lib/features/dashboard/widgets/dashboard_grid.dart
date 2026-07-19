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
import '../../../engine/what_changed_engine.dart';
import '../../../engine/recovery_engine.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../engine/nutrient_evidence_engine.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../foods/providers/food_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../providers/dashboard_provider.dart';
import 'stat_card.dart';
import 'dashboard_water_card.dart';
import 'confidence_ring.dart';
import 'dashboard_loading_skeleton.dart';
import 'nutrition_progress_card.dart';
import 'weekly_progress_card.dart';
import 'dashboard_meals_timeline.dart';
import 'nutrient_evidence_status_text.dart';
import 'daily_return_card.dart';

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
    final usualBreakfast = ref
        .watch(usualMealsProvider('breakfast'))
        .value
        ?.firstOrNull;
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
    final progressDenominator = (profile.currentWeight - profile.targetWeight)
        .abs();
    final progress = progressDenominator == 0
        ? 1.0
        : ((profile.currentWeight - currentWeight).abs() / progressDenominator)
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

    Future<void> repeatBreakfast() async {
      final candidate = usualBreakfast;
      if (candidate == null) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Repeat usual breakfast?', 'تكرار الفطور المعتاد؟')),
          content: Text(
            tr(
              'The same saved portions and nutrition snapshots will be added to today only after confirmation.',
              'ستُضاف نفس الحصص ولقطات التغذية المحفوظة إلى اليوم بعد التأكيد فقط.',
            ),
          ),
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
      await ref
          .read(mealRepositoryProvider)
          .repeatMeal(candidate: candidate, date: DateTime.now());
      ref.invalidate(usualMealsProvider('breakfast'));
    }

    return Column(
      children: [
        DailyReturnCard(
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
        if (loggingStreak >= 2)
          Semantics(
            liveRegion: true,
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.auto_graph_outlined),
                title: Text(
                  arabic
                      ? 'استمرارية حقيقية: $loggingStreak أيام متتالية'
                      : 'Real consistency: $loggingStreak days in a row',
                ),
                subtitle: Text(
                  arabic
                      ? 'هذا التشجيع مبني فقط على سجلاتك المحلية المتتالية، وليس رسالة عشوائية.'
                      : 'This encouragement comes only from your consecutive local records, not a random quote.',
                ),
              ),
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 900
                ? 5
                : MediaQuery.sizeOf(context).width >= 600
                ? 3
                : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 174,
          ),
          itemBuilder: (context, index) => [
            StatCard(
              title: context.strings.text('Weight'),
              value:
                  '${UnitConverter.weightFromKg(currentWeight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
              icon: Icons.monitor_weight,
              color: Colors.blue,
            ),
            NutritionProgressCard(
              label: context.strings.text('Calories'),
              consumed: calories,
              target: effectiveTargets.calories.toDouble(),
              unit: 'kcal',
              icon: Icons.local_fire_department,
              color: Colors.orange,
            ),
            NutritionProgressCard(
              label: context.strings.text('Protein'),
              consumed: protein,
              target: effectiveTargets.protein.toDouble(),
              unit: 'g',
              icon: Icons.fitness_center,
              color: Colors.green,
            ),
            NutritionProgressCard(
              label: tr('Carbohydrates', 'الكربوهيدرات'),
              consumed: carbs,
              target: effectiveTargets.carbs.toDouble(),
              unit: 'g',
              icon: Icons.grain,
              color: Colors.amber.shade800,
            ),
            NutritionProgressCard(
              label: tr('Fat', 'الدهون'),
              consumed: fats,
              target: effectiveTargets.fats.toDouble(),
              unit: 'g',
              icon: Icons.opacity,
              color: Colors.purple,
            ),
          ][index],
        ),
        const SizedBox(height: 12),
        DashboardWaterCard(
          consumedMl: water,
          targetMl: effectiveTargets.water,
          onAdd: addWater,
        ),
        DashboardMealsTimeline(
          meals: meals,
          onOpenMeal: (type) => context.go('/daily-log?meal=$type'),
          usualBreakfastAvailable: usualBreakfast != null,
          onRepeatBreakfast: repeatBreakfast,
        ),
        Card(
          child: ExpansionTile(
            title: Text(
              tr('Available nutrient evidence', 'أدلة العناصر المتاحة'),
            ),
            subtitle: Text(
              tr(
                'Calculated only from logged food portions; unavailable nutrients are not shown as zero.',
                'تُحسب فقط من حصص الطعام المسجلة؛ ولا تظهر العناصر غير المتاحة على أنها صفر.',
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        ),
        WeeklyProgressCard(
          start: UnitConverter.weightFromKg(weekStartWeight, system),
          today: UnitConverter.weightFromKg(currentWeight, system),
          goal: UnitConverter.weightFromKg(profile.targetWeight, system),
          unit: UnitConverter.weightUnit(system),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${tr('Goal progress', 'التقدم نحو الهدف')} ${(progress * 100).round()}%',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Text(
                  arabic
                      ? 'الاحتياج اليومي المقدر ${bil.tdee.round()} سعرة · هدف السعرات ${effectiveTargets.calories}'
                      : 'Estimated TDEE ${bil.tdee.round()} kcal · planned ${goalType == 'lose'
                            ? 'deficit'
                            : goalType == 'gain'
                            ? 'surplus'
                            : 'maintenance'} ${effectiveTargets.calories - bil.tdee.round()} kcal',
                ),
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
          ),
        ),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(intelligence.score?.toString() ?? '—'),
            ),
            title: Text(localizedInsightTitle),
            subtitle: Text(
              arabic
                  ? 'يستند هذا الاستنتاج إلى بياناتك المحلية المسجلة فقط. راجع الدليل واجمع أيامًا إضافية قبل تغيير الخطة.'
                  : '${primaryInsight.explanation}\n${primaryInsight.suggestedAction}',
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
                  context.strings.text('One best action'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  localizedBestTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(localizedBestReason),
                const SizedBox(height: 8),
                Text(
                  arabic
                      ? 'الدليل: بيانات اليوم المسجلة محليًا'
                      : 'Evidence: ${bestAction.evidence.join(' · ')}',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                    TextButton(
                      onPressed: () => respondToAction('dismissed'),
                      child: Text(tr('Dismiss', 'تجاهل')),
                    ),
                  ],
                ),
                if (!memoryEnabled)
                  Text(
                    tr(
                      'Decision Memory is off. Actions remain visible, but responses and outcomes are not stored.',
                      'ذاكرة القرارات متوقفة. تظل الإجراءات ظاهرة، لكن الردود والنتائج لا تُحفظ.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        Card(
          child: ExpansionTile(
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
                    }} · اضغط لمعرفة البيانات الناقصة'
                  : '${honesty.reliability.name} reliability · tap to see what is missing',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (honesty.strengths.isNotEmpty && !arabic)
                Text('Evidence: ${honesty.strengths.join(' · ')}'),
              if (honesty.missing.isNotEmpty && !arabic)
                Text('Improve confidence: ${honesty.missing.join(' · ')}'),
              if (arabic)
                Text(
                  'أيام الوزن: ${weightDays.length} · أيام التغذية: ${mealDays.length} · أيام الماء: ${waterDays.length}. تتحسن الثقة مع اكتمال البيانات وثبات ظروف القياس.',
                ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            title: Text(context.strings.text('What changed today?')),
            subtitle: Text(localizedChanged),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        ),
        Card(
          child: ExpansionTile(
            title: Text(context.strings.text('Body Twin')),
            subtitle: Text(
              arabic
                  ? twin.sufficient
                        ? 'سيناريو حذر متاح من أدلتك المحلية'
                        : 'يتعلم بأمان · نحتاج أيام وزن وتغذية وملاحظة أكثر'
                  : twin.sufficient
                  ? 'Cautious scenario available from your local evidence'
                  : 'Learning safely · ${twin.requiredData.join(' · ')}',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (twin.scenario != null) ...[
                Text(
                  '${tr('Expected planning direction', 'اتجاه التخطيط المتوقع')}: ${twin.scenario!.expectedWeeklyKg.toStringAsFixed(2)} ${tr('kg/week', 'كجم/أسبوع')}',
                ),
                Text(
                  '${tr('Cautious range', 'النطاق الحذر')}: ${twin.scenario!.cautiousLowKg.toStringAsFixed(2)} ${tr('to', 'إلى')} ${twin.scenario!.cautiousHighKg.toStringAsFixed(2)} ${tr('kg/week', 'كجم/أسبوع')}',
                ),
                Text(
                  arabic
                      ? 'الافتراضات: اكتمال التسجيل نسبيًا وثبات النشاط وظروف القياس. لا يمكن تحديد تغير الدهون أو العضلات من الميزان وحده.'
                      : 'Assumptions: ${twin.scenario!.assumptions.join(' · ')}',
                ),
              ],
            ],
          ),
        ),
      ],
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
    return ListTile(
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
    );
  }
}

class _UnavailableNutrientRow extends StatelessWidget {
  const _UnavailableNutrientRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.help_outline),
      title: Text(label),
      subtitle: const NutrientEvidenceStatusText(
        state: NutrientEvidenceState.unavailable,
      ),
      trailing: const Text('—'),
    );
  }
}
