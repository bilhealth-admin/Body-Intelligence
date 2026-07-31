import '../../../data/database/app_database.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../../engine/plan_engine.dart';
import '../domain/dashboard_intelligence_composer.dart';

/// Adapts persisted dashboard records to the engine-facing input contract.
///
/// This is deliberately a one-way boundary: database rows may enter here, while
/// the intelligence composer remains independent of Drift and repositories.
final class DashboardIntelligenceInputAdapter {
  const DashboardIntelligenceInputAdapter();

  DashboardIntelligenceInput adapt({
    required DateTime now,
    required UserProfileData profile,
    required List<WeightEntry> weights,
    required List<MealWithItems> todayMeals,
    required List<WaterEntry> todayWater,
    required List<MealWithItems> allMeals,
    required List<WaterEntry> allWater,
    required List<LifeContextEntry> todayContexts,
    required List<LifeContextEntry> allContexts,
    required List<DecisionMemory> memories,
    required bool skippedWeightToday,
    required PlanSetting? planSetting,
  }) {
    return DashboardIntelligenceInput(
      now: now,
      profile: DashboardProfileInput(
        age: profile.age,
        gender: profile.gender,
        heightCm: profile.height,
        currentWeightKg: profile.currentWeight,
        targetWeightKg: profile.targetWeight,
        activityLevel: profile.activityLevel,
        exercises: profile.exercises,
        neckCm: profile.neck,
        waistCm: profile.waist,
      ),
      weights: [..._adaptWeights(weights)],
      todayMeals: [..._adaptMeals(todayMeals)],
      todayWater: [..._adaptWater(todayWater)],
      allMeals: [..._adaptMeals(allMeals)],
      allWater: [..._adaptWater(allWater)],
      insightContexts: [
        for (final row in todayContexts)
          if (row.useInInsights)
            DashboardContextInput(dayKey: row.dayKey, type: row.type),
      ],
      allContexts: [
        for (final row in allContexts)
          DashboardContextInput(dayKey: row.dayKey, type: row.type),
      ],
      memories: [
        for (final row in memories)
          DashboardDecisionMemoryInput(
            recommendationKey: row.recommendationKey,
            helpfulness: row.helpfulness,
          ),
      ],
      skippedWeightToday: skippedWeightToday,
      planOverrides: planSetting == null
          ? null
          : PlanOverrides(
              calories: planSetting.overrideCalories,
              protein: planSetting.overrideProtein,
              carbs: planSetting.overrideCarbs,
              fats: planSetting.overrideFats,
              fiber: planSetting.overrideFiber,
              water: planSetting.overrideWater,
            ),
    );
  }

  Iterable<DashboardWeightInput> _adaptWeights(List<WeightEntry> rows) sync* {
    for (final row in rows) {
      yield DashboardWeightInput(
        at: row.date,
        kg: row.weight,
        measurementContext: row.measurementContext,
        dayKey: row.dayKey,
      );
    }
  }

  Iterable<DashboardMealInput> _adaptMeals(List<MealWithItems> rows) sync* {
    for (final row in rows) {
      yield DashboardMealInput(
        at: row.meal.date,
        dayKey: row.meal.dayKey,
        items: [
          for (final item in row.items)
            DashboardMealItemInput(
              calories: item.calories,
              protein: item.protein,
              fats: item.fats,
              sodium: item.sodium,
              fiber: item.fiber,
              nutrientEvidenceMask: item.nutrientEvidenceMask,
            ),
        ],
      );
    }
  }

  Iterable<DashboardWaterInput> _adaptWater(List<WaterEntry> rows) sync* {
    for (final row in rows) {
      yield DashboardWaterInput(
        at: row.occurredAt,
        dayKey: row.dayKey,
        amountMl: row.amountMl,
      );
    }
  }
}
