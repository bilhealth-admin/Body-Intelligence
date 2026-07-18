import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/water_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('daily repository keeps one record per local day', () async {
    final repository = DailyLogRepository(database);
    await repository.save(date: DateTime(2026, 7, 18, 8), notes: 'morning');
    await repository.save(date: DateTime(2026, 7, 18, 20), notes: 'evening');

    final rows = await repository.getAll();
    expect(rows, hasLength(1));
    expect(rows.single.notes, 'evening');
    expect(rows.single.dayKey, '2026-07-18');
  });

  test('meal items enforce references and cascade with their meal', () async {
    final foods = FoodRepository(database);
    final meals = MealRepository(database);
    final foodId = await foods.addFood(
      name: 'Oats',
      category: 'grain',
      calories: 389,
      protein: 16.9,
      carbs: 66.3,
      fats: 6.9,
    );
    final mealId = await meals.createMeal(
      date: DateTime(2026, 7, 18),
      name: 'Breakfast',
      type: 'breakfast',
    );
    await meals.addMealItem(
      mealId: mealId,
      foodId: foodId,
      quantity: 50,
      calories: 194.5,
      protein: 8.45,
      carbs: 33.15,
      fats: 3.45,
    );

    await (database.delete(
      database.meals,
    )..where((row) => row.id.equals(mealId))).go();
    expect(await database.select(database.mealItems).get(), isEmpty);
  });

  test('food search matches Arabic names and favorites are unique', () async {
    final foods = FoodRepository(database);
    final id = await foods.addFood(
      name: 'Lentils',
      arabicName: 'عدس',
      category: 'legume',
      calories: 116,
      protein: 9,
      carbs: 20,
      fats: 0.4,
    );
    expect((await foods.search('عدس')).single.id, id);
    await foods.setFavorite(id, true);
    await foods.setFavorite(id, true);
    expect(await database.select(database.favorites).get(), hasLength(1));
    await foods.recordRecent(id);
    await foods.recordRecent(id);
    expect(
      (await database.select(database.recentFoods).getSingle()).useCount,
      2,
    );
  });

  test('weight supports add update and soft delete', () async {
    final weights = WeightRepository(database);
    final id = await weights.addWeight(80, date: DateTime(2026, 7, 1));
    await weights.updateWeight(
      id: id,
      weight: 79.5,
      date: DateTime(2026, 7, 1),
    );
    expect((await weights.getAll()).single.weight, 79.5);
    await weights.deleteWeight(id);
    expect(await weights.getAll(), isEmpty);
  });

  test(
    'daily weight check-in preserves one active entry and durable id',
    () async {
      final weights = WeightRepository(database);
      final morning = DateTime(2026, 7, 18, 7);
      final firstId = await weights.addWeight(
        80,
        date: morning,
        measurementContext: 'morning',
      );
      final firstUuid = (await weights.getForDay(morning))!.uuid;

      final secondId = await weights.addWeight(
        79.8,
        date: morning.add(const Duration(hours: 8)),
        measurementContext: 'afterBathroom',
      );

      final entry = await weights.getForDay(morning);
      expect(secondId, firstId);
      expect(entry!.uuid, firstUuid);
      expect(entry.weight, 79.8);
      expect(entry.measurementContext, 'afterBathroom');
      expect(await weights.getAll(), hasLength(1));
    },
  );

  test(
    'deleted daily weight can be recorded again without resurrection',
    () async {
      final weights = WeightRepository(database);
      final date = DateTime(2026, 7, 18);
      final deletedId = await weights.addWeight(80, date: date);
      await weights.deleteWeight(deletedId);

      final replacementId = await weights.addWeight(79.9, date: date);

      expect(replacementId, isNot(deletedId));
      expect((await weights.getForDay(date))!.weight, 79.9);
      expect(await weights.getAll(), hasLength(1));
    },
  );

  test('water totals are calculated from individual entries', () async {
    final water = WaterRepository(database);
    final date = DateTime(2026, 7, 18);
    await water.add(
      occurredAt: date.add(const Duration(hours: 8)),
      amountMl: 250,
    );
    await water.add(
      occurredAt: date.add(const Duration(hours: 12)),
      amountMl: 400,
    );
    expect(await water.totalForDay(date), 650);
  });

  test('profile edits update the singleton row', () async {
    final profiles = UserProfileRepository(database);
    Future<void> save(double weight) => profiles.save(
      gender: 'female',
      age: 32,
      height: 168,
      currentWeight: weight,
      targetWeight: 65,
      activityLevel: 'moderate',
      exercises: true,
    );
    await save(72);
    await save(71);
    expect(await database.select(database.userProfile).get(), hasLength(1));
    expect((await profiles.getProfile())!.currentWeight, 71);
  });

  test('meal type is reused for the same day', () async {
    final meals = MealRepository(database);
    final first = await meals.createMeal(
      date: DateTime(2026, 7, 18, 8),
      name: 'Breakfast',
      type: 'breakfast',
    );
    final second = await meals.createMeal(
      date: DateTime(2026, 7, 18, 10),
      name: 'Breakfast',
      type: 'breakfast',
    );
    expect(second, first);
    expect(await database.select(database.meals).get(), hasLength(1));
  });
}
