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
        servingSize: 100,
        servingUnit: 'g',
        calories: 100,
        protein: 10,
        carbs: 8,
        fats: 3,
      );
      final frequentId = await foods.addFood(
        name: 'Frequent oats',
        category: 'grain',
        servingSize: 100,
        servingUnit: 'g',
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
        servingSize: 100,
        servingUnit: 'g',
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

  test('multi-day copy is durable and all-or-nothing on conflict', () async {
    final foods = FoodRepository(database);
    final meals = MealRepository(database);
    final foodId = await foods.addFood(
      name: 'Local lentils',
      category: 'legume',
      servingSize: 100,
      servingUnit: 'g',
      calories: 116,
      protein: 9,
      carbs: 20,
      fats: 0.4,
    );
    final source = DateTime(2026, 8, 11);
    final mealId = await meals.createMeal(
      date: source,
      name: 'Lunch',
      type: 'lunch',
    );
    await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 1);
    final targets = [DateTime(2026, 8, 12), DateTime(2026, 8, 13)];

    final copied = await meals.copyDayToDates(
      sourceDate: source,
      destinationDates: targets,
    );
    expect(copied.values, everyElement(1));
    expect(await database.select(database.meals).get(), hasLength(3));
    expect(await database.select(database.mealItems).get(), hasLength(3));

    final emptyTargets = [DateTime(2026, 8, 14), DateTime(2026, 8, 12)];
    await expectLater(
      meals.copyDayToDates(sourceDate: source, destinationDates: emptyTargets),
      throwsStateError,
    );
    expect(await database.select(database.meals).get(), hasLength(3));
  });

  test(
    'quick macro entry persists an immutable snapshot consumed by the diary',
    () async {
      final meals = MealRepository(database);
      final date = DateTime(2026, 8, 11);

      await meals.addQuickMacroEntry(
        date: date,
        mealType: 'snack',
        calories: 210,
        protein: 12,
        carbohydrates: 25,
        fat: 7,
        caloriesKnown: true,
        proteinKnown: true,
        carbohydratesKnown: true,
        fatKnown: true,
        occurredAt: DateTime(2000, 1, 1, 14, 35),
      );

      final diaryMeals = await meals.watchMealsForDate(date).first;
      expect(diaryMeals, hasLength(1));
      expect(diaryMeals.single.meal.type, 'snack');
      expect(diaryMeals.single.items, hasLength(1));
      final item = diaryMeals.single.items.single;
      expect(item.calories, 210);
      expect(item.protein, 12);
      expect(item.carbs, 25);
      expect(item.fats, 7);
      expect(item.foodSourceSnapshot, 'quick_add');
      expect(item.nutrientEvidenceMask, greaterThan(0));
      expect(
        diaryMeals.single.foodsById[item.foodId]?.name,
        'Quick Add • 14:35',
      );

      await expectLater(
        meals.addQuickMacroEntry(
          date: date,
          mealType: 'snack',
          calories: 0,
          protein: 0,
          carbohydrates: 0,
          fat: 0,
          caloriesKnown: true,
          proteinKnown: true,
          carbohydratesKnown: true,
          fatKnown: true,
        ),
        throwsArgumentError,
      );
      await expectLater(
        meals.addQuickMacroEntry(
          date: date,
          mealType: 'snack',
          calories: -1,
          protein: 0,
          carbohydrates: 0,
          fat: 0,
          caloriesKnown: true,
          proteinKnown: true,
          carbohydratesKnown: true,
          fatKnown: true,
        ),
        throwsArgumentError,
      );
    },
  );
}
