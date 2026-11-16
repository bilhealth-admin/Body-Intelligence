import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<MealWithItems> sourceDiary(DateTime date) async {
    final meals = MealRepository(database);
    await meals.addQuickMacroEntry(
      date: date,
      mealType: 'breakfast',
      calories: 174,
      protein: 10,
      carbohydrates: 20,
      fat: 6,
      caloriesKnown: true,
      proteinKnown: true,
      carbohydratesKnown: true,
      fatKnown: true,
    );
    return (await meals.watchMealsForDate(date).first).single;
  }

  Future<List<Object?>> diaryRows() async => [
    for (final row in await database.select(database.meals).get()) row.toJson(),
    for (final row in await database.select(database.mealItems).get())
      row.toJson(),
  ];

  Map<String, dynamic> evidenceSnapshot(MealItem item) =>
      Map.of(item.toJson())..removeWhere(
        (key, _) => const {
          'id',
          'uuid',
          'mealId',
          'createdAt',
          'updatedAt',
          'revision',
          'syncStatus',
          'deletedAt',
        }.contains(key),
      );

  test(
    'copy fills an existing empty bucket without replacing its metadata',
    () async {
      final meals = MealRepository(database);
      final source = await sourceDiary(DateTime(2026, 10, 26));
      final target = DateTime(2026, 10, 27);
      final bucketId = await meals.createMeal(
        date: target,
        name: 'My empty breakfast',
        type: 'breakfast',
      );
      final before = await database.select(database.meals).get();
      final bucket = before.singleWhere((m) => m.id == bucketId);

      expect(
        await meals.copyDay(
          sourceDate: source.meal.date,
          destinationDate: target,
        ),
        1,
      );

      final copied = (await meals.watchMealsForDate(target).first).single;
      expect(copied.meal.toJson(), bucket.toJson());
      expect(copied.items, hasLength(1));
      expect(
        evidenceSnapshot(copied.items.single),
        evidenceSnapshot(source.items.single),
      );
      expect(copied.items.single.uuid, isNot(source.items.single.uuid));
      expect(await database.select(database.meals).get(), hasLength(2));
    },
  );

  test(
    'copy ignores empty source buckets and preserves destination tombstones',
    () async {
      final meals = MealRepository(database);
      final source = await sourceDiary(DateTime(2026, 10, 26));
      await meals.createMeal(
        date: source.meal.date,
        name: 'Empty lunch',
        type: 'lunch',
      );
      final target = DateTime(2026, 10, 27);
      final removed = await sourceDiary(target);
      await meals.deleteMealItem(removed.items.single.id);
      final deleted = (await database.select(database.mealItems).get())
          .singleWhere((i) => i.id == removed.items.single.id);

      expect(
        await meals.copyDay(
          sourceDate: source.meal.date,
          destinationDate: target,
        ),
        1,
      );

      final targetMeals = await meals.watchMealsForDate(target).first;
      expect(targetMeals, hasLength(1));
      expect(targetMeals.single.meal.id, removed.meal.id);
      expect(targetMeals.single.items, hasLength(1));
      expect(
        evidenceSnapshot(targetMeals.single.items.single),
        evidenceSnapshot(source.items.single),
      );
      final afterDeleted = (await database.select(database.mealItems).get())
          .singleWhere((i) => i.id == deleted.id);
      expect(afterDeleted.toJson(), deleted.toJson());
    },
  );

  test(
    'multi-day copy accepts empty headers but never overwrites an active entry',
    () async {
      final meals = MealRepository(database);
      final source = await sourceDiary(DateTime(2026, 10, 26));
      final targets = [DateTime(2026, 10, 27), DateTime(2026, 10, 28)];
      for (final date in targets) {
        await meals.createMeal(
          date: date,
          name: 'Empty breakfast',
          type: 'breakfast',
        );
      }
      final result = await meals.copyDayToDates(
        sourceDate: source.meal.date,
        destinationDates: targets,
      );
      expect(result.values, everyElement(1));
      final before = await diaryRows();
      await expectLater(
        meals.copyDayToDates(
          sourceDate: source.meal.date,
          destinationDates: [DateTime(2026, 10, 29), targets.last],
        ),
        throwsStateError,
      );
      expect(await diaryRows(), before);
    },
  );

  test(
    'multi-day copy preserves closed empty days and rolls back every destination',
    () async {
      final meals = MealRepository(database);
      final source = await sourceDiary(DateTime(2026, 10, 26));
      final open = DateTime(2026, 10, 27);
      final closed = DateTime(2026, 10, 28);
      final daily = DailyLogRepository(database);
      await daily.startDay(closed);
      await daily.closeDay(closed);
      final before = await diaryRows();

      await expectLater(
        meals.copyDayToDates(
          sourceDate: source.meal.date,
          destinationDates: [open, closed],
        ),
        throwsA(
          isA<CoachMealConflict>().having(
            (error) => error.reason,
            'reason',
            CoachMealConflictReason.closedDay,
          ),
        ),
      );
      expect(await diaryRows(), before);
      expect((await daily.readLedger(closed)).state, DayLifecycleState.closed);
    },
  );

  test(
    'copy preserves separate legacy source buckets sharing the same meal type',
    () async {
      final meals = MealRepository(database);
      final source = await sourceDiary(DateTime(2026, 10, 26));
      final secondSourceId = await database
          .into(database.meals)
          .insert(
            MealsCompanion.insert(
              date: source.meal.date,
              dayKey: source.meal.dayKey,
              name: const Value('Second legacy breakfast'),
              type: const Value('breakfast'),
            ),
          );
      await meals.addMealItem(
        mealId: secondSourceId,
        foodId: source.items.single.foodId,
        quantity: 1,
      );
      final target = DateTime(2026, 10, 27);
      final targetId = await meals.createMeal(
        date: target,
        name: 'Existing empty breakfast',
        type: 'breakfast',
      );
      final original = (await database.select(database.meals).get())
          .singleWhere((m) => m.id == targetId);

      expect(
        await meals.copyDay(
          sourceDate: source.meal.date,
          destinationDate: target,
        ),
        2,
      );

      final copied = await meals.watchMealsForDate(target).first;
      expect(copied, hasLength(2));
      expect(copied.map((m) => m.items.length), everyElement(1));
      expect(
        copied.singleWhere((m) => m.meal.id == targetId).meal.toJson(),
        original.toJson(),
      );
      expect(
        copied.singleWhere((m) => m.meal.id != targetId).meal.name,
        'Second legacy breakfast',
      );
    },
  );

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
