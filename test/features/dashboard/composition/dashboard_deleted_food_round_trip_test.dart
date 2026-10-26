import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/dashboard/composition/dashboard_intelligence_input_adapter.dart';
import 'package:body_intelligence_log/features/dashboard/domain/dashboard_intelligence_composer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'last food deletion clears meal completion and undo restores it once',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'deleted-food-owner',
      );
      addTearDown(database.close);
      final at = DateTime(2026, 10, 26, 12);
      final profile = UserProfileData(
        id: 1,
        uuid: 'deleted-food-profile',
        gender: 'male',
        age: 35,
        height: 178,
        currentWeight: 82,
        targetWeight: 76,
        activityLevel: 'moderate',
        exercises: true,
        createdAt: at,
        updatedAt: at,
        revision: 1,
        syncStatus: 'local',
      );
      final foodId = await FoodRepository(database).addFood(
        name: 'Round trip apple',
        category: 'fruit',
        calories: 52,
        protein: 0.3,
        carbs: 14,
        fats: 0.2,
        servingSize: 100,
        servingUnit: 'g',
      );
      final repository = MealRepository(database);
      await repository.addReviewedMealItemsAtomically(
        date: at,
        mealType: 'breakfast',
        items: [(foodId: foodId, quantity: 100)],
        quantitiesInGrams: false,
      );
      Future<DashboardIntelligenceSnapshot> read() async {
        final today = await repository.watchMealsForDate(at).first;
        final history = await repository.watchAll().first;
        return const DashboardIntelligenceComposer().compose(
          const DashboardIntelligenceInputAdapter().adapt(
            now: at,
            profile: profile,
            weights: const [],
            todayMeals: today,
            todayWater: const [],
            allMeals: history,
            allWater: const [],
            dailyLogs: const [],
            todayContexts: const [],
            allContexts: const [],
            memories: const [],
            skippedWeightToday: false,
            planSetting: null,
          ),
        );
      }

      final added = await read();
      expect(added.dailyReturn.hasMeals, isTrue);
      expect(added.calories, 52);
      expect(added.weeklyReview.nutritionDays, 1);
      final item = (await database.select(database.mealItems).get()).single;
      await repository.deleteMealItem(item.id);
      final deleted = await read();
      expect(deleted.dailyReturn.hasMeals, isFalse);
      expect(deleted.loggingStreak, 0);
      expect(deleted.weeklyReview.nutritionDays, 0);
      expect(deleted.calorieByDay, isEmpty);
      expect(deleted.nutrition.hasItems, isFalse);
      // Preserve the tombstone for sync and safe undo; never delete the row
      // merely to make the completion indicator disappear.
      final tombstone =
          (await database.select(database.mealItems).get()).single;
      expect(tombstone.deletedAt, isNotNull);
      expect(tombstone.syncStatus, 'pendingDelete');
      await repository.restoreMealItem(item.id);
      final restored = await read();
      expect(restored.dailyReturn.hasMeals, isTrue);
      expect(restored.calories, 52);
      expect(restored.weeklyReview.nutritionDays, 1);
      expect(await database.select(database.mealItems).get(), hasLength(1));
    },
  );
}
