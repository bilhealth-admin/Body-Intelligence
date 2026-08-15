import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
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
    final foodId = await database
        .into(database.foods)
        .insert(
          FoodsCompanion.insert(
            name: 'Known meal',
            calories: 200,
            protein: 10,
            carbs: 30,
            fats: 5,
          ),
        );
    final mealId = await database
        .into(database.meals)
        .insert(
          MealsCompanion.insert(
            date: day,
            dayKey: dayKeyFor(day),
            type: const Value('lunch'),
          ),
        );
    await database
        .into(database.mealItems)
        .insert(
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

  test(
    'completion is explicit per day and records a closure timestamp',
    () async {
      final firstDay = DateTime(2026, 7, 24, 19, 30);
      final secondDay = DateTime(2026, 7, 25, 7, 15);

      await repository.startDay(firstDay);
      await repository.closeDay(firstDay);

      final first = await repository.getForDay(firstDay);
      expect(first, isNotNull);
      expect(first!.lifecycleState, 'closed');
      expect(first.closedAt, isNotNull);
      expect(
        (await repository.readLedger(firstDay)).state,
        DayLifecycleState.closed,
      );
      expect(
        (await repository.readLedger(secondDay)).state,
        DayLifecycleState.notStarted,
        reason: 'Completing one diary day must not complete adjacent days.',
      );
    },
  );

  test(
    'quick macros preserve selected day, timestamp, and exact totals',
    () async {
      final meals = MealRepository(database);
      final selectedDay = DateTime(2026, 7, 20);
      await meals.addQuickMacroEntry(
        date: selectedDay,
        mealType: 'snack',
        calories: 321,
        protein: 22,
        carbohydrates: 33,
        fat: 11,
        caloriesKnown: true,
        proteinKnown: true,
        carbohydratesKnown: true,
        fatKnown: true,
        occurredAt: DateTime(2026, 7, 20, 16, 45),
      );

      final logged = await meals.watchMealsForDate(selectedDay).first;
      expect(logged, hasLength(1));
      expect(logged.single.meal.date.hour, 16);
      expect(logged.single.meal.date.minute, 45);
      expect(logged.single.items.single.calories, 321);
      expect(logged.single.items.single.protein, 22);
      expect(logged.single.items.single.carbs, 33);
      expect(logged.single.items.single.fats, 11);
    },
  );

  test(
    'quick macros distinguish blank nutrients from an explicit zero',
    () async {
      final meals = MealRepository(database);
      final selectedDay = DateTime(2026, 7, 21);
      await meals.addQuickMacroEntry(
        date: selectedDay,
        mealType: 'snack',
        calories: 210,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
        caloriesKnown: true,
        proteinKnown: true,
        carbohydratesKnown: false,
        fatKnown: false,
      );

      final logged = await meals.watchMealsForDate(selectedDay).first;
      final mask = logged.single.items.single.nutrientEvidenceMask;
      expect(
        NutrientEvidenceMask.contains(mask, TrackedNutrient.calories),
        isTrue,
      );
      expect(
        NutrientEvidenceMask.contains(mask, TrackedNutrient.protein),
        isTrue,
      );
      expect(
        NutrientEvidenceMask.contains(mask, TrackedNutrient.carbohydrates),
        isFalse,
      );
      expect(NutrientEvidenceMask.contains(mask, TrackedNutrient.fat), isFalse);

      await expectLater(
        meals.addQuickMacroEntry(
          date: selectedDay,
          mealType: 'snack',
          calories: 50,
          protein: 2,
          carbohydrates: 0,
          fat: 0,
          caloriesKnown: true,
          proteinKnown: false,
          carbohydratesKnown: false,
          fatKnown: false,
        ),
        throwsArgumentError,
      );
    },
  );
}
