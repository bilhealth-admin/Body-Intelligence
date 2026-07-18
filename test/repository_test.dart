import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
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
}
