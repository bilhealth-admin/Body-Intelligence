import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/units/measurement_units.dart';
import '../../../engine/body_composition_engine.dart';
import '../../../engine/data_honesty_engine.dart';
import '../../../engine/one_best_action_engine.dart';
import '../../connected_health/widgets/connected_health_card.dart';
import '../../../app/theme/premium_design_tokens.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../analytics/analytics_page.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../composition/dashboard_command_coordinator.dart';
import '../composition/dashboard_intelligence_input_adapter.dart';
import '../domain/dashboard_intelligence_composer.dart';
import '../domain/dashboard_decision_explanation.dart';
import '../domain/dashboard_trusted_truth_decision_adapter.dart';
export '../domain/dashboard_intelligence_composer.dart'
    show consecutiveLoggingDays;
import '../domain/dashboard_runtime_state.dart';
import '../presentation/dashboard_intelligence_localizer.dart';
import '../providers/dashboard_provider.dart';
import 'dashboard_analytics_center.dart';
import 'dashboard_body_profile_snapshot.dart';
import 'dashboard_daily_summary.dart';
import 'dashboard_data_gate.dart';
import 'dashboard_loading_skeleton.dart';
import 'dashboard_motion_reveal.dart';
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
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final hydrationCommand = DashboardHydrationCommand(
      onAddWater: (occurredAt, amountMl) => ref
          .read(waterRepositoryProvider)
          .add(occurredAt: occurredAt, amountMl: amountMl),
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
    final localizer = DashboardIntelligenceLocalizer(arabic: arabic);
    String compositionValue(
      BodyCompositionMetric metric, {
      required String unit,
    }) => localizer.compositionValue(metric, unit: unit);
    final localizedBestTitle = localizer.bestActionTitle(bestAction);
    final localizedBestReason = localizer.bestActionReason(bestAction);
    final localizedChanged = localizer.changedSummary(changed);
    final primaryInsight = intelligence.insights.first;
    final localizedInsightTitle = localizer.insightTitle(primaryInsight.title);
    final localizedActionEvidence = bestAction.evidence.isEmpty
        ? tr('Evidence is still forming', 'الأدلة لا تزال قيد التكوين')
        : arabic
        ? 'يستند إلى بياناتك المحلية المسجلة المتاحة.'
        : bestAction.evidence.join(' · ');
    final localizedConfidence = switch (honesty.reliability) {
      DataReliability.insufficient => tr(
        'Insufficient evidence',
        'الأدلة غير كافية',
      ),
      DataReliability.emerging => tr('Emerging', 'قيد التكوين'),
      DataReliability.useful => tr('Useful', 'مفيدة'),
      DataReliability.strong => tr('Strong', 'قوية'),
    };
    final decisionExplanation = DashboardDecisionExplanation(
      actionType: bestAction.type.name,
      title: localizedBestTitle,
      reason: localizedBestReason,
      evidence: bestAction.evidence,
      confidence: localizedConfidence,
      missingEvidence: honesty.missing,
      engineVersion: DashboardTrustedTruthDecisionAdapter.engineVersion,
      inputSources: DashboardTrustedTruthDecisionAdapter.inputEvidenceKeys,
    );

    Future<void> addWater(int amountMl) async {
      await hydrationCommand.addWater(amountMl);
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
            actionEvidence: localizedActionEvidence,
            confidence: localizedConfidence,
            missingEvidence: honesty.missing.isEmpty
                ? ''
                : honesty.missing.join(' · '),
            onExplain: () => context.push(
              '/dashboard/decision-explanation',
              extra: decisionExplanation,
            ),
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
        const SizedBox(height: PremiumDesignTokens.spaceMd),
        DashboardAnalyticsCenter(
          title: tr('Analytics Center', 'مركز التحليلات'),
          weightJourney: weightJourney,
          weeklyProgress: weeklyProgress,
          bodyProfile: bodyProfile,
        ),
      ],
    );
  }
}
