import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/localization/bil_locale_policy.dart';
import 'package:go_router/go_router.dart';

import '../../../core/units/measurement_units.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../../engine/body_composition_engine.dart';
import '../../../engine/data_honesty_engine.dart';
import '../../../engine/one_best_action_engine.dart';
import '../../connected_health/widgets/connected_health_card.dart';
import '../../connected_health/providers/connected_health_provider.dart';
import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../exercise_calorie_controls/domain/exercise_calorie_policy.dart';
import '../../exercise_calorie_controls/providers/exercise_calorie_providers.dart';
import '../../ai_platform/providers/product_intelligence_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../daily_log/providers/daily_log_provider.dart';
import '../../life_context/providers/life_context_provider.dart';
import '../../nutrition/domain/macro_gram_goals.dart';
import '../../nutrition/domain/percentage_nutrition_goals.dart';
import '../dashboard_five_locale_copy.dart';
import '../../weight/providers/weight_provider.dart';
import '../composition/dashboard_command_coordinator.dart';
import '../composition/dashboard_intelligence_input_adapter.dart';
import '../domain/dashboard_intelligence_composer.dart';
import '../domain/dashboard_decision_explanation.dart';
import '../domain/dashboard_trusted_body_twin_adapter.dart';
import '../domain/dashboard_runtime_state.dart';
import '../domain/nutrient_dashboard.dart';
import '../presentation/dashboard_intelligence_localizer.dart';
import '../presentation/dashboard_body_twin_copy.dart';
import '../providers/dashboard_provider.dart';
import '../providers/dashboard_preferences_provider.dart';
import '../providers/dashboard_retry.dart';
import 'dashboard_data_gate.dart';
import 'dashboard_loading_skeleton.dart';
import 'dashboard_motion_reveal.dart';
import 'dashboard_profile_required_card.dart';
import 'dashboard_summary_factory.dart';
import 'daily_return_card.dart';
import 'premium_dashboard_benchmark.dart';
import 'personal_health_ai_panel.dart';

part 'dashboard_unprofiled_reference.dart';

part 'dashboard_nutrient_goal_cards.dart';

class DashboardGrid extends ConsumerWidget {
  const DashboardGrid({super.key, this.hero});

  final Widget? hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    String tr(String en, String ar) => dashboardFiveLocaleText(en, ar);
    String localized(String value) => AppLocalizations.of(context).text(value);
    String localizedList(List<String> values) =>
        values.map(localized).join(' · ');
    final profileAsync = ref.watch(userProfileProvider);
    final weightsAsync = ref.watch(weightHistoryProvider);
    final latestBodyMeasurement = ref
        .watch(bodyMeasurementHistoryProvider)
        .value
        ?.firstOrNull;
    final mealsAsync = ref.watch(todayMealsProvider);
    final waterAsync = ref.watch(todayWaterProvider);
    final allMealsAsync = ref.watch(allMealsProvider);
    final allWaterAsync = ref.watch(allWaterProvider);
    final dailyLogsAsync = ref.watch(dashboardDailyLogsProvider);
    final skippedWeightAsync = ref.watch(weightReminderSkippedTodayProvider);
    final contextAsync = ref.watch(todayLifeContextProvider);
    final allContextsAsync = ref.watch(insightLifeContextProvider);
    final memoriesAsync = ref.watch(decisionMemoriesProvider);
    final clock = ref.watch(dashboardClockProvider);
    final verifiedPlan =
        ref.watch(verifiedSubscriptionStateProvider).value?.plan ??
        CommercePlan.free;
    final premiumUnlocked = verifiedPlan != CommercePlan.free;
    final visibleSections = DashboardSectionIds.all
        .where(
          (section) =>
              ref.watch(dashboardSectionVisibleProvider(section)).value ??
              DashboardSectionIds.defaultVisible(section),
        )
        .toSet();
    final nutrientGoalCardsAsync = ref.watch(
      dashboardNutrientGoalCardsProvider,
    );
    final nutrientGoalStates = <String, AsyncValue<double?>>{
      DashboardNutrientGoalIds.protein: ref.watch(
        dashboardNutrientGoalProvider('goal.proteinGrams'),
      ),
      DashboardNutrientGoalIds.carbohydrates: ref.watch(
        dashboardNutrientGoalProvider('goal.carbsGrams'),
      ),
      DashboardNutrientGoalIds.fat: ref.watch(
        dashboardNutrientGoalProvider('goal.fatGrams'),
      ),
      DashboardNutrientGoalIds.fiber: ref.watch(
        dashboardNutrientGoalProvider('goal.fiber'),
      ),
      DashboardNutrientGoalIds.sodium: ref.watch(
        dashboardNutrientGoalProvider('goal.sodium'),
      ),
      DashboardNutrientGoalIds.potassium: ref.watch(
        dashboardNutrientGoalProvider('goal.potassium'),
      ),
    };
    final system =
        ref.watch(measurementSystemProvider).value ?? MeasurementSystem.metric;
    final hydrationCommand = DashboardHydrationCommand(
      onAddWater: (occurredAt, amountMl) => ref
          .read(waterRepositoryProvider)
          .add(occurredAt: occurredAt, amountMl: amountMl),
      clock: clock,
    );
    final runtimeState = DashboardRuntimeState.fromRequired([
      profileAsync,
      weightsAsync,
      mealsAsync,
      waterAsync,
      allMealsAsync,
      allWaterAsync,
      dailyLogsAsync,
      skippedWeightAsync,
      contextAsync,
      allContextsAsync,
      memoriesAsync,
    ]);
    if (!runtimeState.isReady) {
      return DashboardDataGate(
        state: runtimeState,
        onRetry: () => DashboardRetry.invalidate(ref),
      );
    }
    if (nutrientGoalCardsAsync.isLoading ||
        nutrientGoalStates.values.any((state) => state.isLoading)) {
      return const DashboardLoadingSkeleton();
    }
    if (nutrientGoalCardsAsync.hasError ||
        nutrientGoalStates.values.any((state) => state.hasError)) {
      return DashboardDataGate(
        state: const DashboardRuntimeState.failed(),
        onRetry: () => DashboardRetry.invalidate(ref),
      );
    }
    final nutrientGoalCards = nutrientGoalCardsAsync.requireValue;
    // Protein and carbohydrate progress already live in the primary daily
    // nutrition summary. Do not repeat them as standalone dashboard cards.
    final visibleNutrientGoalCards = nutrientGoalCards.difference(const {
      DashboardNutrientGoalIds.protein,
      DashboardNutrientGoalIds.carbohydrates,
    });
    final nutrientGoals = nutrientGoalStates.map(
      (id, state) => MapEntry(id, state.requireValue),
    );
    final profile = profileAsync.value;
    if (profile == null) {
      return _UnprofiledReferenceDashboard(
        hero: hero,
        message: tr(
          'Complete your profile to calculate personalized targets.',
          'أكمل ملفك الشخصي لحساب أهدافك المخصصة.',
        ),
        actionLabel: tr('Complete profile', 'أكمل الملف الشخصي'),
        onAction: () => context.push('/profile-settings'),
      );
    }
    final planAsync = ref.watch(planSettingProvider(profile.uuid));
    if (planAsync.isLoading) {
      return const DashboardLoadingSkeleton();
    }
    final weights = weightsAsync.value ?? const [];
    final meals = mealsAsync.value ?? const [];
    final todayMealItems = meals.expand((meal) => meal.items).toList();
    final nutrientDashboardPreset = ref
        .watch(dashboardNutrientDashboardProvider)
        .value;
    final nutrientSamples = [
      for (final item in todayMealItems)
        NutrientDashboardSample(
          evidenceMask: item.nutrientEvidenceMask,
          values: {
            TrackedNutrient.protein: item.protein,
            TrackedNutrient.carbohydrates: item.carbs,
            TrackedNutrient.fat: item.fats,
            TrackedNutrient.fiber: item.fiber,
            TrackedNutrient.sugar: item.sugar,
            TrackedNutrient.sodium: item.sodium,
            TrackedNutrient.potassium: item.potassium,
          },
        ),
    ];
    double? evidenced(TrackedNutrient nutrient) =>
        NutrientDashboardEvidence.total(nutrientSamples, nutrient).value;
    final persistedSodiumGoal = nutrientGoals[DashboardNutrientGoalIds.sodium];
    final persistedFiberGoal = nutrientGoals[DashboardNutrientGoalIds.fiber];
    final carbohydrates = todayMealItems.fold<double>(
      0,
      (sum, item) => sum + item.carbs,
    );
    final dashboardFiber = todayMealItems.fold<double>(
      0,
      (sum, item) => sum + item.fiber,
    );
    final dashboardSugar = todayMealItems.fold<double>(
      0,
      (sum, item) => sum + item.sugar,
    );
    final dashboardSodium = todayMealItems.fold<double>(
      0,
      (sum, item) => sum + item.sodium,
    );
    final waterRows = waterAsync.value ?? const [];
    final allMeals = allMealsAsync.value ?? const [];
    final allWater = allWaterAsync.value ?? const [];
    final dailyLogs = dailyLogsAsync.value ?? const [];
    final allContexts = allContextsAsync.value ?? const [];
    final now = clock();
    final canonicalIntelligence = ref.watch(productIntelligenceOutputProvider);
    final goalSchedule =
        ref.watch(nutritionGoalScheduleProvider).value ??
        const NutritionGoalSchedule();
    final scheduledTarget = goalSchedule.targetFor(now);
    final dashboardSnapshot = const DashboardIntelligenceComposer().compose(
      const DashboardIntelligenceInputAdapter().adapt(
        now: now,
        profile: profile,
        weights: weights,
        todayMeals: meals,
        todayWater: waterRows,
        allMeals: allMeals,
        allWater: allWater,
        dailyLogs: dailyLogs,
        todayContexts: contextAsync.value ?? const [],
        allContexts: allContexts,
        memories: memoriesAsync.value ?? const [],
        skippedWeightToday: skippedWeightAsync.value ?? false,
        planSetting: planAsync.value,
        latestBodyMeasurement: latestBodyMeasurement,
        dailyNutritionTarget: scheduledTarget,
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
    final savedMacroGramGoals = ref.watch(dashboardMacroGramGoalsProvider);
    final macroGramGoals = scheduledTarget == null
        ? savedMacroGramGoals
        : const MacroGramGoals();
    final savedPercentageGoals = ref.watch(
      dashboardPercentageNutritionGoalsProvider,
    );
    final percentageGoals = scheduledTarget == null
        ? savedPercentageGoals
        : PercentageNutritionGoals.resolve(
            calories: scheduledTarget.calories,
            carbohydratesPercent: scheduledTarget.carbsPercent,
            proteinPercent: scheduledTarget.proteinPercent,
            fatPercent: scheduledTarget.fatPercent,
          );
    final cardNutrientGoals = <String, double?>{
      ...nutrientGoals,
      DashboardNutrientGoalIds.protein:
          macroGramGoals.protein ?? percentageGoals?.proteinGrams,
      DashboardNutrientGoalIds.carbohydrates:
          macroGramGoals.carbohydrates ?? percentageGoals?.carbohydratesGrams,
      DashboardNutrientGoalIds.fat:
          macroGramGoals.fat ?? percentageGoals?.fatGrams,
    };
    final exercisePreferences =
        ref.watch(exerciseCaloriePreferencesProvider).value ??
        const ExerciseCaloriePreferences();
    final exerciseEnergy = authoritativeExerciseEnergyForDay(
      ref.watch(connectedHealthProvider).value,
      now,
    );
    final exerciseAdjustedTargets = ExerciseCaloriePolicy.calculate(
      preferences: exercisePreferences,
      day: now,
      baseCalorieGoal:
          percentageGoals?.calories ?? effectiveTargets.calories.toDouble(),
      consumedCalories: calories,
      baseProteinGoal: macroGramGoals.proteinOr(
        percentageGoals?.proteinGrams ?? effectiveTargets.protein.toDouble(),
      ),
      baseCarbohydrateGoal: macroGramGoals.carbohydratesOr(
        percentageGoals?.carbohydratesGrams ??
            effectiveTargets.carbs.toDouble(),
      ),
      baseFatGoal: macroGramGoals.fatOr(
        percentageGoals?.fatGrams ?? effectiveTargets.fats.toDouble(),
      ),
      energy: exerciseEnergy,
    );
    final loggingStreak = dashboardSnapshot.loggingStreak;
    final intelligence = dashboardSnapshot.intelligence;
    final honesty = dashboardSnapshot.honesty;
    final bestAction = dashboardSnapshot.bestAction;
    final changed = dashboardSnapshot.changed;
    final dailyReturn = dashboardSnapshot.dailyReturn;
    final twin = dashboardSnapshot.bodyTwin;
    final fallbackTwin = dashboardSnapshot.trustedBodyTwin;
    final canonicalBody = canonicalIntelligence.value?.bodyTwinResult;
    final canonicalWeight = canonicalBody?.acceptedSnapshot?.observationFor(
      'weight',
    );
    final trustedTwin = canonicalBody == null
        ? fallbackTwin
        : canonicalBody.canProceed && canonicalWeight != null
        ? DashboardTrustedBodyTwinSnapshot(
            status: DashboardBodyTwinTrustStatus.trusted,
            engineVersion: 'reality-runtime-body-twin-v1',
            reasons: const [
              'Canonical Reality Runtime accepted the local Body Twin snapshot.',
            ],
            weightKg: canonicalWeight.value,
            observedAt: canonicalWeight.observedAt,
            source: canonicalWeight.source,
          )
        : DashboardTrustedBodyTwinSnapshot(
            status: DashboardBodyTwinTrustStatus.unavailable,
            engineVersion: 'reality-runtime-body-twin-v1',
            reasons: canonicalBody.integrityIssues.isEmpty
                ? const [
                    'Canonical Reality Runtime did not accept a Body Twin snapshot.',
                  ]
                : canonicalBody.integrityIssues,
          );
    final chronologicalWeights = weights.reversed.toList();
    final localizer = DashboardIntelligenceLocalizer(
      arabic: arabic,
    ).forLocale(BilLocalePolicy.canonicalTag(Localizations.localeOf(context)));
    final firstBodyTwinReading =
        trustedTwin.canExposeBodyTwin && chronologicalWeights.length == 1;
    String compositionValue(
      BodyCompositionMetric metric, {
      required String unit,
    }) => localizer.compositionValue(metric, unit: unit);
    final canonicalOutput = canonicalIntelligence.value;
    final canonicalAction = canonicalOutput?.brainResult.selectedAction;
    final localizedBestTitle = canonicalOutput == null
        ? localizer.bestActionTitle(bestAction)
        : (canonicalAction == null ? null : localized(canonicalAction.title)) ??
              tr('No plan change today', 'لا تغيير على الخطة اليوم');
    final localizedBestReason = canonicalOutput == null
        ? localizer.bestActionReason(bestAction)
        : canonicalAction == null
        ? localized(canonicalOutput.primaryMessage)
        : localized(canonicalAction.rationale);
    final localizedChanged = localizer.changedSummary(changed);
    final primaryInsight = intelligence.insights.first;
    final localizedInsightTitle = localizer.insightTitle(primaryInsight.title);
    final rawDecisionEvidence =
        canonicalOutput?.brainResult.evidenceIds.toList() ??
        bestAction.evidence;
    final localizedActionEvidence = rawDecisionEvidence.isEmpty
        ? localizer.evidenceGap()
        : localizer.evidenceSummary();
    final localizedConfidence = canonicalOutput != null
        ? '${(canonicalOutput.brainResult.confidence * 100).round()}%'
        : switch (honesty.reliability) {
            DataReliability.insufficient => tr(
              'Insufficient evidence',
              'الأدلة غير كافية',
            ),
            DataReliability.emerging => tr('Emerging', 'قيد التكوين'),
            DataReliability.useful => tr('Useful', 'مفيدة'),
            DataReliability.strong => tr('Strong', 'قوية'),
          };
    final decisionExplanation = DashboardDecisionExplanation(
      actionType: localizedBestTitle,
      title: localizedBestTitle,
      reason: localizedBestReason,
      evidence: [localizedActionEvidence],
      confidence: localizedConfidence,
      missingEvidence:
          (canonicalOutput == null
                  ? honesty.missing
                  : [
                      ...canonicalOutput.brainResult.reconciliationIssues,
                      for (final signal in canonicalOutput.brainResult.signals)
                        if (!signal.accepted) ...signal.reasons,
                    ])
              .isEmpty
          ? const []
          : [localizer.evidenceGap()],
      engineVersion: 'BIL',
      inputSources: [localizer.evidenceSummary()],
    );
    final twinCopy = DashboardBodyTwinCopy.compose(
      trusted: trustedTwin,
      report: twin,
      firstReading: firstBodyTwinReading,
      tr: tr,
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

    void openCanonicalAction() {
      switch (canonicalAction?.id) {
        case 'continue-plan':
          context.push('/plan?origin=dashboard');
        case 'increase-protein':
        case 'rebalance-electrolytes':
          context.go('/daily-log?meal=breakfast&focus=meal&from=%2Fdashboard');
        case 'protect-sleep':
        case 'increase-activity':
          context.go('/daily-log?from=%2Fdashboard');
        case 'audit-plateau-inputs':
          context.go('/analytics');
        case null:
          break;
        default:
          context.push('/intelligence-center');
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
    final progressSection = DashboardSummaryFactory.build(
      tr: tr,
      arabic: arabic,
      loggingStreak: loggingStreak,
      mealsEmpty: meals.isEmpty,
      calories: calories.round(),
      protein: protein.round(),
      fats: fats.round(),
      fiber: fiberEvidence.total,
      dailyRequirement: bil.tdee.round(),
      weight: UnitConverter.weightFromKg(
        currentWeight,
        system,
      ).toStringAsFixed(1),
      weightUnit: UnitConverter.weightUnit(system),
      bodyFat: compositionValue(bodyComposition.bodyFatPercentage, unit: ''),
      bodyFatUnit: bodyComposition.bodyFatPercentage.isAvailable ? '%' : '',
      fatFreeMass: bodyComposition.fatFreeMassKg.isAvailable
          ? '${UnitConverter.weightFromKg(bodyComposition.fatFreeMassKg.value!, system).toStringAsFixed(1)} '
                '${UnitConverter.weightUnit(system)}'
          : '—',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardMotionReveal(
          child: PremiumDashboardBenchmark(
            hero: hero,
            arabic: arabic,
            showRecommendation: canonicalOutput == null
                ? bestAction.type == BestActionType.protein
                : canonicalAction?.id == 'increase-protein',
            actionTitle: localizedBestTitle,
            actionReason: localizedBestReason,
            actionEvidence: localizedActionEvidence,
            confidence: localizedConfidence,
            missingEvidence: canonicalOutput != null
                ? (canonicalOutput.brainResult.reconciliationIssues.isEmpty
                      ? ''
                      : localizedList(
                          canonicalOutput.brainResult.reconciliationIssues,
                        ))
                : honesty.missing.isEmpty
                ? ''
                : localizedList(honesty.missing),
            onExplain: () => context.push(
              '/dashboard/decision-explanation',
              extra: decisionExplanation,
            ),
            onAction: canonicalOutput != null
                ? (canonicalAction == null ? null : openCanonicalAction)
                : dailyReturn.hasPrimaryAction
                ? () {
                    switch (bestAction.type) {
                      case BestActionType.weighIn:
                        context.push('/daily-check-in');
                      case BestActionType.completeLogging:
                      case BestActionType.protein:
                        context.go(
                          '/daily-log?meal=breakfast&focus=meal&from=%2Fdashboard',
                        );
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
              onWeightTap: () => context.push('/daily-check-in'),
              onMealsTap: () => context.go(
                '/daily-log?meal=breakfast&focus=meal&from=%2Fdashboard',
              ),
              onWaterTap: () => context.go('/daily-log?from=%2Fdashboard'),
            ),
            progressSection: progressSection,
            personalHealthAi: personalHealthAiPanel,
            connectedHealth: ConnectedHealthCard(
              languageCode: Localizations.localeOf(context).languageCode,
              compact: MediaQuery.sizeOf(context).width < 600,
              dashboardCompact: MediaQuery.sizeOf(context).width < 600,
            ),
            bodyTwinSummary: twinCopy.summary,
            bodyTwinEvidence: twinCopy.evidence,
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
            trendSummary: firstBodyTwinReading
                ? tr(
                    'Your first trusted baseline is ready',
                    'خط أساسك الأول الموثوق جاهز',
                  )
                : localizedChanged,
            trendEvidence: changed.evidence.isEmpty
                ? firstBodyTwinReading
                      ? tr(
                          'One trusted reading · direction requires comparable future readings',
                          'قراءة موثوقة واحدة · يحتاج الاتجاه إلى قراءات لاحقة قابلة للمقارنة',
                        )
                      : tr(
                          'Comparable observations are still forming',
                          'الملاحظات القابلة للمقارنة لا تزال قيد التكوين',
                        )
                : localizedList(changed.evidence),
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
            caloriesConsumed: calories.round(),
            caloriesGoal: exerciseAdjustedTargets.effectiveCalorieGoal.round(),
            baseCaloriesGoal: exerciseAdjustedTargets.baseCalorieGoal.round(),
            caloriesBurned: exerciseEnergy?.kcal.round() ?? 0,
            netCalories: (calories - (exerciseEnergy?.kcal ?? 0)).round(),
            remainingCalories: exerciseAdjustedTargets.remainingCalories
                .round(),
            burnedCaloriesApplied:
                exerciseAdjustedTargets.availability ==
                ExerciseCalorieAvailability.applied,
            proteinConsumed: protein.round(),
            proteinGoal: exerciseAdjustedTargets.proteinGoal.round(),
            carbohydratesConsumed: carbohydrates.round(),
            carbohydratesGoal: exerciseAdjustedTargets.carbohydrateGoal.round(),
            fatConsumed: fats.round(),
            fatGoal: exerciseAdjustedTargets.fatGoal.round(),
            fiberConsumed: dashboardFiber.round(),
            sugarConsumed: dashboardSugar.round(),
            sodiumConsumed: dashboardSodium.round(),
            carbohydratesEvidenceValue: evidenced(
              TrackedNutrient.carbohydrates,
            ),
            fiberEvidenceValue: evidenced(TrackedNutrient.fiber),
            sugarEvidenceValue: evidenced(TrackedNutrient.sugar),
            sodiumEvidenceValue: evidenced(TrackedNutrient.sodium),
            fiberGoal: persistedFiberGoal?.round(),
            sodiumGoal: persistedSodiumGoal?.round(),
            nutrientDashboardPreset:
                nutrientDashboardPreset ?? 'Calories and macros',
            weightTrendValues: weights
                .take(90)
                .map(
                  (entry) => UnitConverter.weightFromKg(entry.weight, system),
                )
                .toList(growable: false)
                .reversed
                .toList(growable: false),
            stepTrendValues: dailyLogs
                .where((entry) => entry.steps != null)
                .take(30)
                .map((entry) => entry.steps!.toDouble())
                .toList(growable: false)
                .reversed
                .toList(growable: false),
            weightUnit: UnitConverter.weightUnit(system),
            visibleSections: visibleSections,
            premiumUnlocked: premiumUnlocked,
          ),
        ),
        if (visibleNutrientGoalCards.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _DashboardNutrientGoalCards(
              selected: visibleNutrientGoalCards,
              values: {
                DashboardNutrientGoalIds.protein: evidenced(
                  TrackedNutrient.protein,
                ),
                DashboardNutrientGoalIds.carbohydrates: evidenced(
                  TrackedNutrient.carbohydrates,
                ),
                DashboardNutrientGoalIds.fat: evidenced(TrackedNutrient.fat),
                DashboardNutrientGoalIds.fiber: evidenced(
                  TrackedNutrient.fiber,
                ),
                DashboardNutrientGoalIds.sodium: evidenced(
                  TrackedNutrient.sodium,
                ),
                DashboardNutrientGoalIds.potassium: evidenced(
                  TrackedNutrient.potassium,
                ),
              },
              goals: cardNutrientGoals,
            ),
          ),
      ],
    );
  }
}
