import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/dashboard/composition/dashboard_intelligence_input_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardIntelligenceInputAdapter', () {
    test('preserves persisted values at the composition boundary', () {
      final at = DateTime(2026, 7, 31, 8, 30);
      final input = const DashboardIntelligenceInputAdapter().adapt(
        now: at,
        profile: _profile(at),
        weights: [_weight(at)],
        todayMeals: [_meal(at)],
        todayWater: [_water(at)],
        allMeals: [_meal(at)],
        allWater: [_water(at)],
        todayContexts: [
          _context(at, id: 1, type: 'sleep', useInInsights: true),
          _context(at, id: 2, type: 'travel', useInInsights: false),
        ],
        allContexts: [
          _context(at, id: 1, type: 'sleep', useInInsights: true),
          _context(at, id: 2, type: 'travel', useInInsights: false),
        ],
        memories: [_memory(at)],
        skippedWeightToday: true,
        planSetting: _plan(at),
      );

      expect(input.now, at);
      expect(input.profile.age, 35);
      expect(input.profile.gender, 'male');
      expect(input.profile.heightCm, 178);
      expect(input.profile.currentWeightKg, 82);
      expect(input.profile.targetWeightKg, 76);
      expect(input.profile.neckCm, 39);
      expect(input.profile.waistCm, 91);

      expect(input.weights.single.at, at);
      expect(input.weights.single.kg, 81.5);
      expect(input.weights.single.dayKey, '2026-07-31');
      expect(input.weights.single.measurementContext, 'morning');

      final meal = input.todayMeals.single;
      expect(meal.at, at);
      expect(meal.dayKey, '2026-07-31');
      expect(meal.items.single.calories, 420);
      expect(meal.items.single.protein, 31);
      expect(meal.items.single.fats, 12);
      expect(meal.items.single.sodium, 560);
      expect(meal.items.single.fiber, 7);
      expect(meal.items.single.nutrientEvidenceMask, 9);

      expect(input.todayWater.single.amountMl, 350);
      expect(input.insightContexts.single.type, 'sleep');
      expect(input.allContexts.map((row) => row.type), ['sleep', 'travel']);
      expect(input.memories.single.recommendationKey, 'hydrate');
      expect(input.memories.single.helpfulness, 4);
      expect(input.skippedWeightToday, isTrue);
      expect(input.planOverrides!.calories, 2100);
      expect(input.planOverrides!.protein, 150);
      expect(input.planOverrides!.water, 2800);
    });

    test('keeps nullable plan overrides absent when no plan exists', () {
      final at = DateTime(2026, 7, 31);
      final input = const DashboardIntelligenceInputAdapter().adapt(
        now: at,
        profile: _profile(at),
        weights: const [],
        todayMeals: const [],
        todayWater: const [],
        allMeals: const [],
        allWater: const [],
        todayContexts: const [],
        allContexts: const [],
        memories: const [],
        skippedWeightToday: false,
        planSetting: null,
      );

      expect(input.planOverrides, isNull);
      expect(input.weights, isEmpty);
      expect(input.todayMeals, isEmpty);
      expect(input.insightContexts, isEmpty);
    });
  });
}

UserProfileData _profile(DateTime at) => UserProfileData(
  id: 1,
  uuid: 'profile-1',
  gender: 'male',
  age: 35,
  height: 178,
  currentWeight: 82,
  targetWeight: 76,
  activityLevel: 'moderate',
  exercises: true,
  waist: 91,
  neck: 39,
  createdAt: at,
  updatedAt: at,
  revision: 1,
  syncStatus: 'synced',
);

WeightEntry _weight(DateTime at) => WeightEntry(
  id: 1,
  uuid: 'weight-1',
  date: at,
  dayKey: '2026-07-31',
  weight: 81.5,
  measurementContext: 'morning',
  createdAt: at,
  updatedAt: at,
  revision: 1,
  syncStatus: 'synced',
);

MealWithItems _meal(DateTime at) => MealWithItems(
  meal: Meal(
    id: 1,
    uuid: 'meal-1',
    date: at,
    dayKey: '2026-07-31',
    name: 'Breakfast',
    type: 'breakfast',
    createdAt: at,
    updatedAt: at,
    revision: 1,
    syncStatus: 'synced',
  ),
  items: [
    MealItem(
      id: 1,
      uuid: 'item-1',
      mealId: 1,
      foodId: 1,
      quantity: 1,
      position: 0,
      calories: 420,
      protein: 31,
      carbs: 48,
      fats: 12,
      fiber: 7,
      sodium: 560,
      potassium: 0,
      calcium: 0,
      magnesium: 0,
      phosphorus: 0,
      sugar: 0,
      nutrientEvidenceMask: 9,
      createdAt: at,
      updatedAt: at,
      revision: 1,
      syncStatus: 'synced',
    ),
  ],
);

WaterEntry _water(DateTime at) => WaterEntry(
  id: 1,
  uuid: 'water-1',
  occurredAt: at,
  dayKey: '2026-07-31',
  amountMl: 350,
  createdAt: at,
  updatedAt: at,
  revision: 1,
  syncStatus: 'synced',
);

LifeContextEntry _context(
  DateTime at, {
  required int id,
  required String type,
  required bool useInInsights,
}) => LifeContextEntry(
  id: id,
  uuid: 'context-$id',
  occurredAt: at,
  dayKey: '2026-07-31',
  type: type,
  useInInsights: useInInsights,
  createdAt: at,
  updatedAt: at,
  revision: 1,
  syncStatus: 'synced',
);

DecisionMemory _memory(DateTime at) => DecisionMemory(
  id: 1,
  uuid: 'memory-1',
  dayKey: '2026-07-31',
  recommendationKey: 'hydrate',
  title: 'Hydrate',
  reason: 'Below target',
  evidenceJson: '{}',
  confidence: 'high',
  response: 'done',
  helpfulness: 4,
  surfacedAt: at,
  revision: 1,
  syncStatus: 'synced',
);

PlanSetting _plan(DateTime at) => PlanSetting(
  id: 1,
  uuid: 'plan-1',
  profileUuid: 'profile-1',
  recommendedCalories: 2000,
  recommendedProtein: 140,
  recommendedCarbs: 220,
  recommendedFats: 65,
  recommendedFiber: 30,
  recommendedWater: 2500,
  overrideCalories: 2100,
  overrideProtein: 150,
  overrideWater: 2800,
  assumptionsVersion: 'v1',
  createdAt: at,
  updatedAt: at,
  revision: 1,
  syncStatus: 'synced',
);
