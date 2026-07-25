import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DailyLogRepository repository;
  final day = DateTime(2026, 7, 25, 8);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DailyLogRepository(database);
  });
  tearDown(() => database.close());

  test('day opens, closes to an authoritative snapshot, and reopens', () async {
    await repository.startDay(day);
    final foodId = await database.into(database.foods).insert(
      FoodsCompanion.insert(
        name: 'Known meal',
        calories: 200,
        protein: 10,
        carbs: 30,
        fats: 5,
      ),
    );
    final mealId = await database.into(database.meals).insert(
      MealsCompanion.insert(
        date: day,
        dayKey: dayKeyFor(day),
        type: const Value('lunch'),
      ),
    );
    await database.into(database.mealItems).insert(
      MealItemsCompanion.insert(
        mealId: mealId,
        foodId: foodId,
        calories: const Value(200),
        protein: const Value(10),
        carbs: const Value(30),
        fats: const Value(5),
        fiber: const Value(8),
        nutrientEvidenceMask: Value(
          NutrientEvidenceMask.bit(TrackedNutrient.fiber),
        ),
      ),
    );

    final open = await repository.readLedger(day);
    expect(open.state, DayLifecycleState.open);
    expect(open.netCarbohydrates, 22);

    await repository.closeDay(day);
    await (database.update(database.mealItems)
          ..where((item) => item.mealId.equals(mealId)))
        .write(const MealItemsCompanion(calories: Value(999)));
    final closed = await repository.readLedger(day);
    expect(closed.state, DayLifecycleState.closed);
    expect(closed.calories, 200);

    await repository.reopenDay(day);
    final reopened = await repository.readLedger(day);
    expect(reopened.state, DayLifecycleState.open);
    expect(reopened.calories, 999);
  });
}
