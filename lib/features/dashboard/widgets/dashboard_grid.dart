import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../core/units/measurement_units.dart';
import '../../../engine/body_composition_engine.dart';
import '../../../engine/data_honesty_engine.dart';
import '../../../engine/one_best_action_engine.dart';
import '../../../engine/what_changed_engine.dart';
import '../../connected_health/widgets/connected_health_card.dart';
import '../../../engine/nutrient_evidence_engine.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../analytics/analytics_page.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../foods/providers/food_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../composition/dashboard_command_coordinator.dart';
import '../composition/dashboard_composition.dart';
import '../composition/dashboard_intelligence_input_adapter.dart';
import '../domain/dashboard_intelligence_composer.dart';
export '../domain/dashboard_intelligence_composer.dart'
    show consecutiveLoggingDays;
import '../domain/dashboard_runtime_state.dart';
import '../providers/dashboard_provider.dart';
import 'dashboard_body_profile_snapshot.dart';
import 'dashboard_daily_summary.dart';
import 'dashboard_data_gate.dart';
import 'dashboard_loading_skeleton.dart';
import 'dashboard_motion_reveal.dart';
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
    final commandCoordinator = DashboardCommandCoordinator(
      onRememberAction: (action) =>
          ref.read(decisionMemoryRepositoryProvider).rememberAction(action),
      onRespondToAction: (memoryId, response) => ref
          .read(decisionMemoryRepositoryProvider)
          .respond(memoryId, response),
      onAddWater: (occurredAt, amountMl) => ref
          .read(waterRepositoryProvider)
          .add(occurredAt: occurredAt, amountMl: amountMl),
      onRepeatUsualMeal: (candidate, date) => ref
          .read(mealRepositoryProvider)
          .repeatMeal(candidate: candidate, date: date),
      onRepeatHistoricalMeal: (meal, date) => ref
          .read(mealRepositoryProvider)
          .repeatHistoricalMeal(meal: meal, date: date),
      clock: DateTime.now,
    );
    final runtimeState = DashboardRuntimeState.fromRequired([
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
    ]);
    if (!runtimeState.isReady) {
      return DashboardDataGate(
        state: runtimeState,
        onRetry: () {
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
    final now = DateTime.now();
    final dashboardSnapshot = const DashboardIntelligenceComposer().compose(
      const DashboardIntelligenceInputAdapter().adapt(
        now: now,
        profile: profile,
        weights: weights,
        todayMeals: meals,
        todayWater: waterRows,
        allMeals: allMeals,
        allWater: allWater,
        todayContexts: contextAsync.value ?? const [],
        allContexts: allContexts,
        memories: memoriesAsync.value ?? const [],
        skippedWeightToday: skippedWeightAsync.value ?? false,
        planSetting: planAsync.value,
      ),
    );
    final calories = dashboardSnapshot.calories;
    final protein = dashboardSnapshot.protein;
    final fats = dashboardSnapshot.fats;
    final water = dashboardSnapshot.waterMl;
    final currentWeight = dashboardSnapshot.currentWeightKg;
    final fiberEvidence = dashboardSnapshot.fiberEvidence;
    final bil = dashboardSnapshot.bil;
    final bodyComposition = dashboardSnapshot.bodyComposition;
    final effectiveTargets = dashboardSnapshot.effectiveTargets;
    final loggingStreak = dashboardSnapshot.loggingStreak;
    final intelligence = dashboardSnapshot.intelligence;
    final honesty = dashboardSnapshot.honesty;
    final bestAction = dashboardSnapshot.bestAction;
    final changed = dashboardSnapshot.changed;
    final dailyReturn = dashboardSnapshot.dailyReturn;
    final twin = dashboardSnapshot.bodyTwin;
    final chronologicalWeights = weights.reversed.toList();
    final progressAnalysis = dashboardSnapshot.progress;
    final recentJourneyWeights = chronologicalWeights.length > 30
        ? chronologicalWeights.sublist(chronologicalWeights.length - 30)
        : chronologicalWeights;
    final weeklyReview = dashboardSnapshot.weeklyReview;
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
      await commandCoordinator.recordActionResponse(
        action: bestAction,
        response: response,
      );
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
      await commandCoordinator.addWater(amountMl);
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
        onConfirm: () => commandCoordinator.repeatUsualBreakfast(candidate),
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
        onConfirm: () =>
            commandCoordinator.repeatRecentBreakfast(latestBreakfast),
      );
    }

    final healthAi = dashboardSnapshot.personalHealthAi;
    final personalHealthAiPanel = PersonalHealthAiPanel(
      snapshot: healthAi,
      arabic: arabic,
      todayHasMeals: meals.isNotEmpty,
      decisionCount: memoriesAsync.value?.length ?? 0,
      compact: MediaQuery.sizeOf(context).width < 600,
    );
    final progressSection = DashboardDailySummarySection(
      title: tr('Daily Summary', 'ملخص اليوم'),
      subtitle: tr(
        'Your recorded nutrition and active daily references.',
        'تغذيتك المسجلة ومراجع يومك النشطة.',
      ),
      badge: loggingStreak >= 2
          ? DashboardStreakBadge(days: loggingStreak, arabic: arabic)
          : null,
      pages: [
        DashboardMetricGridPage(
          metrics: [
            DashboardMetricData(
              Icons.local_fire_department_outlined,
              tr('Calories', 'السعرات'),
              meals.isEmpty ? '—' : calories.round().toString(),
              meals.isEmpty ? '' : 'kcal',
              Colors.orange,
            ),
            DashboardMetricData(
              Icons.fitness_center_outlined,
              tr('Protein', 'البروتين'),
              meals.isEmpty ? '—' : protein.round().toString(),
              meals.isEmpty ? '' : 'g',
              Colors.green,
            ),
            DashboardMetricData(
              Icons.opacity_outlined,
              tr('Fat', 'الدهون'),
              meals.isEmpty ? '—' : fats.round().toString(),
              meals.isEmpty ? '' : 'g',
              Colors.purple,
            ),
            DashboardMetricData(
              Icons.grass_outlined,
              tr('Fiber', 'الألياف'),
              fiberEvidence.total == null
                  ? '—'
                  : fiberEvidence.total!.round().toString(),
              fiberEvidence.total == null ? '' : 'g',
              Colors.lightGreen,
            ),
          ],
        ),
        DashboardMetricGridPage(
          metrics: [
            DashboardMetricData(
              Icons.bolt_outlined,
              tr('Daily Requirement', 'الاحتياج اليومي'),
              bil.tdee.round().toString(),
              'kcal',
              Colors.deepOrangeAccent,
            ),
            DashboardMetricData(
              Icons.monitor_weight_outlined,
              tr('Weight', 'الوزن'),
              UnitConverter.weightFromKg(
                currentWeight,
                system,
              ).toStringAsFixed(1),
              UnitConverter.weightUnit(system),
              Colors.blue,
            ),
            DashboardMetricData(
              Icons.accessibility_new_rounded,
              tr('Body mass index', 'مؤشر كتلة الجسم'),
              compositionValue(bodyComposition.bodyMassIndex, unit: ''),
              bodyComposition.bodyMassIndex.isAvailable ? 'BMI' : '',
              Colors.cyan,
            ),
            DashboardMetricData(
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
    final bodyProfile = DashboardBodyProfileSnapshot(
      arabic: arabic,
      weight:
          '${UnitConverter.weightFromKg(currentWeight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
      height: '${profile.height.toStringAsFixed(1)} cm',
      target:
          '${UnitConverter.weightFromKg(profile.targetWeight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)}',
      calorieTarget: '${effectiveTargets.calories} kcal',
      proteinTarget: '${effectiveTargets.protein} g',
      waterTarget: '${effectiveTargets.water} ml',
      dailyMetabolism: '${bil.tdee.round()} kcal',
      neckCircumference: profile.neck == null
          ? tr('Neck circumference is not recorded', 'محيط الرقبة غير مسجل')
          : '${profile.neck!.toStringAsFixed(1)} cm',
      waistCircumference: profile.waist == null
          ? tr('Waist circumference is not recorded', 'محيط الخصر غير مسجل')
          : '${profile.waist!.toStringAsFixed(1)} cm',
      bodyMassIndex: compositionValue(
        bodyComposition.bodyMassIndex,
        unit: ' BMI',
      ),
      bodyFatPercentage: compositionValue(
        bodyComposition.bodyFatPercentage,
        unit: '%',
      ),
      leanBodyMass: compositionValue(
        bodyComposition.leanBodyMassKg,
        unit: ' kg',
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
        DashboardMotionReveal(
          child: PremiumDashboardBenchmark(
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
            bodyTwinSummary: tr(
              'Current weight ${UnitConverter.weightFromKg(currentWeight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)} · BMI ${compositionValue(bodyComposition.bodyMassIndex, unit: '')} · Body fat ${compositionValue(bodyComposition.bodyFatPercentage, unit: '%')}',
              'الوزن الحالي ${UnitConverter.weightFromKg(currentWeight, system).toStringAsFixed(1)} ${UnitConverter.weightUnit(system)} · مؤشر كتلة الجسم ${compositionValue(bodyComposition.bodyMassIndex, unit: '')} · نسبة الدهون ${compositionValue(bodyComposition.bodyFatPercentage, unit: '%')}',
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
            final layout = DashboardComposition.analytics(
              viewportWidth: MediaQuery.sizeOf(context).width,
              contentWidth: constraints.maxWidth,
            );
            if (!layout.analyticsHorizontal) {
              final phone = layout.isPhone;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!phone) ...[bodyProfile, const SizedBox(height: 12)],
                  Text(
                    tr('Analytics Center', 'مركز التحليلات'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.15,
                      height: 1.12,
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
