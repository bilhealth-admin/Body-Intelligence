import '../../../data/database/date_keys.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../engine/bil_engine.dart';
import '../../../engine/body_composition_engine.dart';
import '../../../engine/body_profile.dart';
import '../../../engine/body_twin_engine.dart';
import '../../../engine/daily_return_engine.dart';
import '../../../engine/daily_targets.dart';
import '../../../engine/data_honesty_engine.dart';
import '../../../engine/intelligence_engine.dart';
import '../../../engine/nutrient_evidence_engine.dart';
import '../../../engine/one_best_action_engine.dart';
import 'dashboard_decision_authority.dart';
import 'dashboard_trusted_body_twin_adapter.dart';
import '../../../engine/plan_engine.dart';
import '../../../engine/progress_analysis.dart';
import '../../../engine/recovery_engine.dart';
import '../../../engine/weekly_review_engine.dart';
import '../../../engine/what_changed_engine.dart';
import '../../ai_platform/domain/personal_health_ai.dart';
import '../../ai_platform/services/personal_health_ai_engine.dart';

class DashboardProfileInput {
  const DashboardProfileInput({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.activityLevel,
    required this.exercises,
    this.neckCm,
    this.waistCm,
    this.hipsCm,
  });

  final int age;
  final String gender;
  final double heightCm;
  final double currentWeightKg;
  final double targetWeightKg;
  final String activityLevel;
  final bool exercises;
  final double? neckCm;
  final double? waistCm;
  final double? hipsCm;
}

class DashboardWeightInput {
  const DashboardWeightInput({
    required this.at,
    required this.kg,
    required this.measurementContext,
    this.dayKey,
  });

  final DateTime at;
  final double kg;
  final String measurementContext;
  final String? dayKey;
}

class DashboardMealItemInput {
  const DashboardMealItemInput({
    required this.calories,
    required this.protein,
    required this.fats,
    required this.sodium,
    required this.fiber,
    required this.nutrientEvidenceMask,
  });

  final double calories;
  final double protein;
  final double fats;
  final double sodium;
  final double fiber;
  final int nutrientEvidenceMask;
}

class DashboardMealInput {
  const DashboardMealInput({
    required this.at,
    required this.dayKey,
    required this.items,
  });

  final DateTime at;
  final String dayKey;
  final List<DashboardMealItemInput> items;
}

class DashboardWaterInput {
  const DashboardWaterInput({
    required this.at,
    required this.dayKey,
    required this.amountMl,
  });

  final DateTime at;
  final String dayKey;
  final int amountMl;
}

class DashboardContextInput {
  const DashboardContextInput({required this.dayKey, required this.type});
  final String dayKey;
  final String type;
}

class DashboardDecisionMemoryInput {
  const DashboardDecisionMemoryInput({
    required this.recommendationKey,
    this.helpfulness,
  });
  final String recommendationKey;
  final int? helpfulness;
}

class DashboardIntelligenceInput {
  const DashboardIntelligenceInput({
    required this.now,
    required this.profile,
    required this.weights,
    required this.todayMeals,
    required this.todayWater,
    required this.allMeals,
    required this.allWater,
    required this.insightContexts,
    required this.allContexts,
    required this.memories,
    required this.skippedWeightToday,
    this.planOverrides,
  });

  final DateTime now;
  final DashboardProfileInput profile;
  final List<DashboardWeightInput> weights;
  final List<DashboardMealInput> todayMeals;
  final List<DashboardWaterInput> todayWater;
  final List<DashboardMealInput> allMeals;
  final List<DashboardWaterInput> allWater;
  final List<DashboardContextInput> insightContexts;
  final List<DashboardContextInput> allContexts;
  final List<DashboardDecisionMemoryInput> memories;
  final bool skippedWeightToday;
  final PlanOverrides? planOverrides;
}

class DashboardIntelligenceSnapshot {
  const DashboardIntelligenceSnapshot({
    required this.calories,
    required this.protein,
    required this.fats,
    required this.sodium,
    required this.waterMl,
    required this.currentWeightKg,
    required this.fiberEvidence,
    required this.bil,
    required this.bodyComposition,
    required this.effectiveTargets,
    required this.loggingStreak,
    required this.intelligence,
    required this.honesty,
    required this.bestAction,
    required this.changed,
    required this.recovery,
    required this.dailyReturn,
    required this.bodyTwin,
    required this.trustedBodyTwin,
    required this.progress,
    required this.recentJourneyWeights,
    required this.weeklyReview,
    required this.calorieByDay,
    required this.personalHealthAi,
  });

  final double calories;
  final double protein;
  final double fats;
  final double sodium;
  final int waterMl;
  final double currentWeightKg;
  final NutrientEvidenceReport fiberEvidence;
  final BILResult bil;
  final BodyCompositionResult bodyComposition;
  final DailyTargets effectiveTargets;
  final int loggingStreak;
  final IntelligenceReport intelligence;
  final DataHonestyReport honesty;
  final BestAction bestAction;
  final WhatChangedReport changed;
  final RecoveryReport recovery;
  final DailyReturnReport dailyReturn;
  final BodyTwinReport bodyTwin;
  final DashboardTrustedBodyTwinSnapshot trustedBodyTwin;
  final ProgressAnalysis progress;
  final List<DashboardWeightInput> recentJourneyWeights;
  final WeeklyReview weeklyReview;
  final Map<DateTime, double?> calorieByDay;
  final PersonalHealthAiSnapshot personalHealthAi;
}

class DashboardIntelligenceComposer {
  const DashboardIntelligenceComposer({
    this._decisionAuthority = const TrustedDashboardDecisionAuthority(),
    this._bodyTwinAdapter = const DashboardTrustedBodyTwinAdapter(),
  });

  final DashboardDecisionAuthority _decisionAuthority;
  final DashboardTrustedBodyTwinAdapter _bodyTwinAdapter;

  DashboardIntelligenceSnapshot compose(DashboardIntelligenceInput input) {
    final todayItems = input.todayMeals.expand((meal) => meal.items).toList();
    final calories = todayItems.fold<double>(
      0,
      (sum, item) => sum + item.calories,
    );
    final protein = todayItems.fold<double>(
      0,
      (sum, item) => sum + item.protein,
    );
    final fats = todayItems.fold<double>(0, (sum, item) => sum + item.fats);
    final sodium = todayItems.fold<double>(0, (sum, item) => sum + item.sodium);
    final fiberEvidence = NutrientEvidenceEngine.total([
      for (final item in todayItems)
        NutrientObservation(
          value: item.fiber,
          available: NutrientEvidenceMask.contains(
            item.nutrientEvidenceMask,
            TrackedNutrient.fiber,
          ),
        ),
    ]);
    final waterMl = input.todayWater.fold<int>(
      0,
      (sum, row) => sum + row.amountMl,
    );
    final currentWeightKg =
        input.weights.firstOrNull?.kg ?? input.profile.currentWeightKg;
    final goalType = input.profile.targetWeightKg < currentWeightKg
        ? 'lose'
        : input.profile.targetWeightKg > currentWeightKg
        ? 'gain'
        : 'maintain';
    final body = BodyProfile(
      age: input.profile.age,
      gender: input.profile.gender,
      height: input.profile.heightCm,
      weight: currentWeightKg,
      targetWeight: input.profile.targetWeightKg,
      activityLevel: input.profile.activityLevel,
      exercises: input.profile.exercises,
      goalType: goalType,
      waistCm: input.profile.waistCm,
      neckCm: input.profile.neckCm,
      hipCm: input.profile.hipsCm,
    );
    final bil = BILEngine.calculate(
      profile: body,
      eatenCalories: calories.round(),
      eatenProtein: protein.round(),
      drankWater: waterMl,
    );
    final bodyComposition = bil.bodyModel.composition;
    final effectiveTargets = PlanEngine.effective(
      bil.targets,
      input.planOverrides,
    );
    final mealDays = input.allMeals.map((row) => row.dayKey).toSet();
    final waterDays = input.allWater.map((row) => row.dayKey).toSet();
    final weightDays = input.weights
        .map((row) => row.dayKey ?? dayKeyFor(row.at))
        .toSet();
    final observedDays = {...mealDays, ...waterDays, ...weightDays};
    final loggingStreak = consecutiveLoggingDays(observedDays, input.now);
    final comparableWeightDays = input.weights
        .where((row) => row.measurementContext != 'differentConditions')
        .length;
    final chronologicalWeights = input.weights.reversed.toList();
    final chronologicalKg = chronologicalWeights.map((row) => row.kg).toList();
    final intelligence = IntelligenceEngine.evaluate(
      calorieTarget: effectiveTargets.calories,
      proteinTarget: effectiveTargets.protein,
      waterTarget: effectiveTargets.water,
      calories: calories,
      protein: protein,
      waterMl: waterMl,
      chronologicalWeights: chronologicalKg,
      goalWeight: input.profile.targetWeightKg,
      sodium: sodium,
      trackedDays: todayItems.isEmpty && input.todayWater.isEmpty ? 0 : 1,
    );
    final honesty = DataHonestyEngine.evaluate(
      observationDays: observedDays.length,
      weightDays: weightDays.length,
      nutritionDays: mealDays.length,
      waterDays: waterDays.length,
      consistentConditionDays: comparableWeightDays,
    );
    final lowRatings = <String, int>{};
    for (final memory in input.memories) {
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
    final todayKey = dayKeyFor(input.now);
    final bestAction = _decisionAuthority.choose(
      weighedToday: weightDays.contains(todayKey) || input.skippedWeightToday,
      loggingComplete: input.todayMeals.isNotEmpty,
      protein: protein,
      proteinTarget: effectiveTargets.protein,
      waterMl: waterMl,
      waterTarget: effectiveTargets.water,
      trackedDays: observedDays.length,
      suppressedTypes: suppressedActions,
    );
    final changed = WhatChangedEngine.compare(
      chronologicalWeights: chronologicalKg,
      comparableConditions:
          input.weights.length >= 2 &&
          input.weights[0].measurementContext ==
              input.weights[1].measurementContext &&
          input.weights[0].measurementContext != 'differentConditions',
      contextTypes: input.insightContexts.map((entry) => entry.type).toList(),
    );
    DateTime? latestTrackedAt;
    void consider(DateTime value) {
      if (latestTrackedAt == null || value.isAfter(latestTrackedAt!)) {
        latestTrackedAt = value;
      }
    }

    for (final row in input.weights) {
      consider(row.at);
    }
    for (final row in input.allMeals) {
      consider(row.at);
    }
    for (final row in input.allWater) {
      consider(row.at);
    }
    final recovery = RecoveryEngine.evaluate(
      now: input.now,
      lastTrackedAt: latestTrackedAt,
    );
    final dailyReturn = DailyReturnEngine.compose(
      hasWeight: weightDays.contains(todayKey),
      hasMeals: input.todayMeals.isNotEmpty,
      hasWater: input.todayWater.isNotEmpty,
      bestAction: bestAction,
      changed: changed,
      honesty: honesty,
      recovery: recovery,
    );
    final bodyTwin = BodyTwinEngine.simulate(
      calorieTarget: effectiveTargets.calories,
      tdee: bil.tdee.round(),
      weightDays: weightDays.length,
      nutritionDays: mealDays.length,
      observationDays: observedDays.length,
    );
    final trustedBodyTwin = _bodyTwinAdapter.build(
      asOf: input.now,
      weights: input.weights.map(
        (weight) => DashboardBodyTwinWeightObservation(
          kg: weight.kg,
          observedAt: weight.at,
          source: weight.measurementContext,
        ),
      ),
    );
    final progress = ProgressAnalysis.evaluate(
      samples: chronologicalWeights
          .map((row) => ProgressSample(date: row.at, weightKg: row.kg))
          .toList(),
      goalWeightKg: input.profile.targetWeightKg,
    );
    final recentJourneyWeights = chronologicalWeights.length > 30
        ? chronologicalWeights.sublist(chronologicalWeights.length - 30)
        : chronologicalWeights;
    final weekCutoff = dayKeyFor(input.now.subtract(const Duration(days: 6)));
    final weeklyReview = WeeklyReviewEngine.evaluate(
      weightDays: chronologicalWeights
          .where((row) => dayKeyFor(row.at).compareTo(weekCutoff) >= 0)
          .map((row) => dayKeyFor(row.at))
          .toSet()
          .length,
      nutritionDays: input.allMeals
          .where((row) => row.dayKey.compareTo(weekCutoff) >= 0)
          .map((row) => row.dayKey)
          .toSet()
          .length,
      waterDays: input.allWater
          .where((row) => row.dayKey.compareTo(weekCutoff) >= 0)
          .map((row) => row.dayKey)
          .toSet()
          .length,
      contextDays: input.allContexts
          .where((row) => row.dayKey.compareTo(weekCutoff) >= 0)
          .map((row) => row.dayKey)
          .toSet()
          .length,
      weeklyWeightChangeKg: progress.weeklyDirectionKg,
    );
    final calorieByDay = <DateTime, double?>{};
    for (final meal in input.allMeals) {
      final day = DateTime(meal.at.year, meal.at.month, meal.at.day);
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
    final personalHealthAi = const PersonalHealthAiEngine().evaluate(
      asOf: input.now,
      weights: [
        for (final weight in input.weights)
          WeightObservation(
            at: weight.at,
            kg: weight.kg,
            comparability: weight.measurementContext == 'sameConditions'
                ? 1
                : 0.65,
          ),
      ],
      age: input.profile.age,
      heightCm: input.profile.heightCm,
      gender: input.profile.gender,
      activityLevel: input.profile.activityLevel,
      dailyCalories: calorieByDay,
    );
    return DashboardIntelligenceSnapshot(
      calories: calories,
      protein: protein,
      fats: fats,
      sodium: sodium,
      waterMl: waterMl,
      currentWeightKg: currentWeightKg,
      fiberEvidence: fiberEvidence,
      bil: bil,
      bodyComposition: bodyComposition,
      effectiveTargets: effectiveTargets,
      loggingStreak: loggingStreak,
      intelligence: intelligence,
      honesty: honesty,
      bestAction: bestAction,
      changed: changed,
      recovery: recovery,
      dailyReturn: dailyReturn,
      bodyTwin: bodyTwin,
      trustedBodyTwin: trustedBodyTwin,
      progress: progress,
      recentJourneyWeights: recentJourneyWeights,
      weeklyReview: weeklyReview,
      calorieByDay: calorieByDay,
      personalHealthAi: personalHealthAi,
    );
  }
}

int consecutiveLoggingDays(Set<String> observedDays, DateTime now) {
  var count = 0;
  var cursor = DateTime(now.year, now.month, now.day);
  while (observedDays.contains(dayKeyFor(cursor))) {
    count += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}
