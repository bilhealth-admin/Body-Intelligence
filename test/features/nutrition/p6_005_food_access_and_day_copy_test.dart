import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'food access ranks favorites then frequency deterministically',
    () async {
      final foods = FoodRepository(database);
      final favoriteId = await foods.addFood(
        name: 'Favorite yogurt',
        category: 'dairy',
        calories: 100,
        protein: 10,
        carbs: 8,
        fats: 3,
      );
      final frequentId = await foods.addFood(
        name: 'Frequent oats',
        category: 'grain',
        calories: 389,
        protein: 16.9,
        carbs: 66.3,
        fats: 6.9,
      );
      await foods.setFavorite(favoriteId, true);
      await foods.recordRecent(frequentId);
      await foods.recordRecent(frequentId);

      final candidates = await foods.foodAccessCandidates();

      expect(candidates.map((entry) => entry.food.localId), <int>[
        favoriteId,
        frequentId,
      ]);
      expect(candidates.first.reasons, contains('favorite'));
      expect(candidates.last.useCount, 2);
    },
  );

  test(
    'copy day preserves snapshots and refuses occupied destination',
    () async {
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final oatsId = await foods.addFood(
        name: 'Oats',
        category: 'grain',
        calories: 389,
        protein: 16.9,
        carbs: 66.3,
        fats: 6.9,
        fiber: 10.6,
        sodium: 2,
        potassium: 429,
      );
      final sourceDate = DateTime(2026, 7, 20, 8);
      final destinationDate = DateTime(2026, 7, 21, 8);
      final mealId = await meals.createMeal(
        date: sourceDate,
        name: 'Breakfast',
        type: 'breakfast',
      );
      await meals.addMealItem(mealId: mealId, foodId: oatsId, quantity: 50);
      final sourceItem = await database.select(database.mealItems).getSingle();

      expect(
        await meals.copyDay(
          sourceDate: sourceDate,
          destinationDate: destinationDate,
        ),
        1,
      );

      final allItems = await database.select(database.mealItems).get();
      expect(allItems, hasLength(2));
      final copied = allItems.singleWhere((item) => item.id != sourceItem.id);
      expect(copied.calories, sourceItem.calories);
      expect(copied.protein, sourceItem.protein);
      expect(copied.nutrientEvidenceMask, sourceItem.nutrientEvidenceMask);

      await expectLater(
        meals.copyDay(sourceDate: sourceDate, destinationDate: destinationDate),
        throwsStateError,
      );
    },
  );
}
