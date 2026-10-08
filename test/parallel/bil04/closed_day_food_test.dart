import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_builder.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final _closedDay = throwsA(
  isA<CoachMealConflict>().having(
    (error) => error.reason,
    'reason',
    CoachMealConflictReason.closedDay,
  ),
);
final _sourceDay = DateTime(2026, 10, 5, 12);
final _targetDay = DateTime(2026, 10, 6, 12);
final _openDay = DateTime(2026, 10, 7, 12);

void main() {
  late _FoodGateStore store;
  setUp(() async {
    store = _FoodGateStore();
    await store.seedFood();
  });
  tearDown(() => store.database.close());

  final mutationCases =
      <String, Future<dynamic> Function(_FoodGateStore, MealWithItems)>{
        'existing bucket lookup': (s, meal) => s.meals.createMeal(
          date: _targetDay,
          name: 'Breakfast',
          type: 'breakfast',
        ),
        'direct item insertion': (s, meal) => s.meals.addMealItem(
          mealId: meal.meal.id,
          foodId: s.foodId,
          quantity: 10,
        ),
        'quantity edit': (s, meal) =>
            s.meals.updateMealItem(id: meal.items.first.id, quantity: 75),
        'item deletion': (s, meal) =>
            s.meals.deleteMealItem(meal.items.first.id),
        'item restore': (s, meal) =>
            s.meals.restoreMealItem(meal.items.first.id),
        'meal cascade deletion': (s, meal) =>
            s.meals.deleteMealCascade(meal.meal.id),
        'item reorder': (s, meal) =>
            s.meals.moveMealItem(id: meal.items.first.id, offset: 1),
        'meal type move': (s, meal) => s.meals.moveMealItemToType(
          id: meal.items.first.id,
          mealType: 'lunch',
        ),
        'same-type move': (s, meal) => s.meals.moveMealItemToType(
          id: meal.items.first.id,
          mealType: 'breakfast',
        ),
        'item duplication': (s, meal) =>
            s.meals.duplicateMealItem(meal.items.first.id),
      };
  for (final entry in mutationCases.entries) {
    test('closed day rejects ${entry.key} without any mutation', () async {
      final meal = await store.seedMeal(_targetDay);
      await store.daily.closeDay(_targetDay);
      final before = await store.snapshot();
      await expectLater(entry.value(store, meal), _closedDay);
      expect(await store.snapshot(), before);
    });
  }

  test('empty closed day blocks every ordinary destination writer', () async {
    final source = await store.seedMeal(_sourceDay);
    await store.daily.startDay(_targetDay);
    await store.daily.closeDay(_targetDay);
    final template = store.meals.createTemplateFromHistoricalMeal(
      meal: source,
      templateId: 'synthetic-template',
      templateName: 'Synthetic breakfast',
      createdAt: _sourceDay,
    );
    final attempts = <Future<dynamic> Function()>[
      () => store.meals.createMeal(
        date: _targetDay,
        name: 'Breakfast',
        type: 'breakfast',
      ),
      () => store.meals.addReviewedMealItemsAtomically(
        date: _targetDay,
        mealType: 'lunch',
        items: [(foodId: store.foodId, quantity: 50.0)],
      ),
      () => store.meals.addQuickMacroEntry(
        date: _targetDay,
        mealType: 'snack',
        calories: 100,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
        caloriesKnown: true,
        proteinKnown: false,
        carbohydratesKnown: false,
        fatKnown: false,
      ),
      () => store.meals.addCalculatedRecipeServingAtomically(
        date: _targetDay,
        mealType: 'dinner',
        foodUuid: 'synthetic-calculated-recipe',
        recipeName: 'Synthetic recipe',
        source: 'synthetic_local_catalog',
        calories: 200,
        protein: 10,
        carbohydrates: 30,
        fat: 4,
      ),
      () => store.meals.copyDay(
        sourceDate: _sourceDay,
        destinationDate: _targetDay,
      ),
      () => store.meals.repeatHistoricalMeal(meal: source, date: _targetDay),
      () => store.meals.repeatMeal(
        candidate: UsualMealCandidate(source: source, occurrences: 2),
        date: _targetDay,
      ),
      () => store.meals.createMealFromDraft(
        draft: MealBuilderDraft(
          name: 'Synthetic draft',
          mealType: 'breakfast',
          items: [
            MealBuilderItemDraft(
              foodId: store.foodId,
              quantityGrams: 50,
              position: 1,
            ),
          ],
        ),
        date: _targetDay,
      ),
      () =>
          store.meals.instantiateTemplate(template: template, date: _targetDay),
    ];
    final before = await store.snapshot();
    for (final attempt in attempts) {
      await expectLater(attempt(), _closedDay);
      expect(await store.snapshot(), before);
    }
    final ledger = await store.daily.readLedger(_targetDay);
    expect(ledger.state, DayLifecycleState.closed);
    expect(ledger.calories, isNull);
    expect(await store.meals.watchMealsForDate(_targetDay).first, isEmpty);
  });

  test(
    'empty source cannot silently succeed when its destination is closed',
    () async {
      await store.daily.startDay(_targetDay);
      await store.daily.closeDay(_targetDay);
      final before = await store.snapshot();
      await expectLater(
        store.meals.copyDay(
          sourceDate: _sourceDay,
          destinationDate: _targetDay,
        ),
        _closedDay,
      );
      expect(await store.snapshot(), before);
    },
  );

  test(
    'multiple destination copy rejects one closed day before any insert',
    () async {
      await store.seedMeal(_sourceDay);
      await store.daily.startDay(_targetDay);
      await store.daily.closeDay(_targetDay);
      final before = await store.snapshot();
      await expectLater(
        store.meals.copyDayToDates(
          sourceDate: _sourceDay,
          destinationDates: [_openDay, _targetDay],
        ),
        _closedDay,
      );
      expect(await store.snapshot(), before);
      expect(await store.meals.watchMealsForDate(_openDay).first, isEmpty);
    },
  );

  test(
    'closed source remains readable and copyable into open destinations',
    () async {
      final source = await store.seedMeal(_sourceDay);
      await store.daily.closeDay(_sourceDay);
      final original = jsonEncode(
        (await store.meals.watchMealsForDate(_sourceDay).first).single.items
            .map((item) => item.toJson())
            .toList(),
      );
      expect(
        await store.meals.copyDay(
          sourceDate: _sourceDay,
          destinationDate: _targetDay,
        ),
        1,
      );
      await store.meals.repeatHistoricalMeal(meal: source, date: _openDay);
      expect(
        (await store.meals.watchMealsForDate(_targetDay).first).single.items
            .map((item) => item.quantity),
        source.items.map((item) => item.quantity),
      );
      expect(
        jsonEncode(
          (await store.meals.watchMealsForDate(_sourceDay).first).single.items
              .map((item) => item.toJson())
              .toList(),
        ),
        original,
      );
      expect(
        (await store.daily.getForDay(_sourceDay))?.lifecycleState,
        'closed',
      );
    },
  );

  for (final state in ['closed', 'closed_at_only']) {
    test('either persisted closure marker fences mutations: $state', () async {
      final meal = await store.seedMeal(_targetDay);
      await (store.database.update(
        store.database.dailyLogs,
      )..where((row) => row.dayKey.equals(dayKeyFor(_targetDay)))).write(
        DailyLogsCompanion(
          lifecycleState: Value(state == 'closed' ? 'closed' : 'open'),
          closedAt: Value(state == 'closed' ? null : _targetDay),
        ),
      );
      final before = await store.snapshot();
      await expectLater(
        store.meals.addMealItem(
          mealId: meal.meal.id,
          foodId: store.foodId,
          quantity: 10,
        ),
        _closedDay,
      );
      await expectLater(
        store.meals.createMeal(
          date: _targetDay,
          name: 'Dinner',
          type: 'dinner',
        ),
        _closedDay,
      );
      expect(await store.snapshot(), before);
    });
  }

  test('deleted item cannot be restored until the day is reopened', () async {
    final meal = await store.seedMeal(_targetDay);
    final id = meal.items.first.id;
    await store.meals.deleteMealItem(id);
    await store.daily.closeDay(_targetDay);
    final tombstone = (await store.meals.getMealItem(id)).toJson();
    await expectLater(store.meals.restoreMealItem(id), _closedDay);
    expect((await store.meals.getMealItem(id)).toJson(), tombstone);
    await store.daily.reopenDay(_targetDay);
    await store.meals.restoreMealItem(id);
    expect((await store.meals.getMealItem(id)).deletedAt, isNull);
  });

  test(
    'explicit reopen allows ordinary edits without changing food semantics',
    () async {
      final meal = await store.seedMeal(_targetDay);
      final id = meal.items.first.id;
      await store.daily.closeDay(_targetDay);
      await store.daily.reopenDay(_targetDay);
      await store.meals.updateMealItem(id: id, quantity: 75);
      final updated = await store.meals.getMealItem(id);
      expect(updated.quantity, 75);
      expect(
        updated.calories,
        closeTo(meal.items.first.calories * 1.5, 0.000001),
      );
      await store.meals.moveMealItemToType(id: id, mealType: 'lunch');
      final duplicated = await store.meals.duplicateMealItem(id);
      await store.meals.moveMealItem(id: id, offset: 1);
      await store.meals.deleteMealItem(duplicated);
      await store.meals.restoreMealItem(duplicated);
      expect((await store.meals.getMealItem(duplicated)).deletedAt, isNull);
      await store.meals.addMealItem(
        mealId: meal.meal.id,
        foodId: store.foodId,
        quantity: 10,
      );
      await store.meals.deleteMealCascade(meal.meal.id);
      expect(await store.meals.getMealTypeForItem(id), 'lunch');
      expect((await store.daily.getForDay(_targetDay))?.lifecycleState, 'open');
    },
  );

  test(
    'pending closure and ordinary insertion serialize in one database',
    () async {
      final meal = await store.seedMeal(_targetDay);
      final closedInsideTransaction = Completer<void>();
      final releaseClosure = Completer<void>();
      final closing = store.database.transaction(() async {
        await store.daily.closeDay(_targetDay);
        closedInsideTransaction.complete();
        await releaseClosure.future;
      });
      await closedInsideTransaction.future;
      final insertion = store.meals.addMealItem(
        mealId: meal.meal.id,
        foodId: store.foodId,
        quantity: 10,
      );
      final rejected = expectLater(insertion, _closedDay);
      releaseClosure.complete();
      await closing;
      await rejected;
      final saved =
          (await store.meals.watchMealsForDate(_targetDay).first).single;
      expect(saved.items.length, 2);
      expect(
        (await store.daily.getForDay(_targetDay))?.lifecycleState,
        'closed',
      );
    },
  );
}

class _FoodGateStore {
  _FoodGateStore()
    : database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'synthetic-food-owner',
      );
  final AppDatabase database;
  late final meals = MealRepository(database);
  late final daily = DailyLogRepository(database);
  late final int foodId;

  Future<void> seedFood() async {
    foodId = await FoodRepository(database).addFood(
      name: 'Synthetic oats',
      category: 'grain',
      servingSize: 100,
      servingUnit: 'g',
      calories: 389,
      protein: 16.9,
      carbs: 66.3,
      fats: 6.9,
      fiber: 8.4,
    );
  }

  Future<MealWithItems> seedMeal(DateTime date) async {
    await daily.startDay(date);
    final mealId = await meals.createMeal(
      date: date,
      name: 'Breakfast',
      type: 'breakfast',
    );
    for (final amount in [50.0, 25.0]) {
      await meals.addMealItem(
        mealId: mealId,
        foodId: foodId,
        quantity: amount,
        quantityInGrams: true,
      );
    }
    return (await meals.watchMealsForDate(date).first).single;
  }

  Future<String> snapshot() async => jsonEncode({
    'foods': (await database.select(database.foods).get())
        .map((row) => row.toJson())
        .toList(),
    'meals': (await database.select(database.meals).get())
        .map((row) => row.toJson())
        .toList(),
    'items': (await database.select(database.mealItems).get())
        .map((row) => row.toJson())
        .toList(),
    'daily': (await database.select(database.dailyLogs).get())
        .map((row) => row.toJson())
        .toList(),
  });
}
