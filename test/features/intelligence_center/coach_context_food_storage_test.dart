import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_context_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../daily_log/daily_log_nutrition_fixtures.dart';
import '../nutrition/food_basis_fixtures.dart';

class _ContextStorage {
  _ContextStorage()
    : db = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'coach-context-owner',
      );

  final AppDatabase db;

  Future<void> save(List<MealItem> items) async {
    await db.into(db.meals).insert(diaryMeal(items).meal.toCompanion(true));
    for (final item in items) {
      await db
          .into(db.foods)
          .insert(
            basisFood()
                .copyWith(id: item.foodId, uuid: 'context-food-${item.foodId}')
                .toCompanion(true),
          );
      await db.into(db.mealItems).insert(item.toCompanion(true));
    }
  }

  Future<List<MealWithItems>> read() => MealRepository(db).watchAll().first;

  Future<CoachNutritionDay> day() async =>
      assembleCoachNutritionDays(await read()).single;
}

_ContextStorage _storage() {
  final storage = _ContextStorage();
  addTearDown(storage.db.close);
  return storage;
}

Map<String, Object?> _savedItem(CoachNutritionDay day) =>
    Map<String, Object?>.from(
      (day.meals.single['items']! as List).single as Map,
    );

void main() {
  test(
    'actual repository read keeps the immutable name after catalog edit',
    () async {
      final storage = _storage();
      await storage.save([modernDiaryItem()]);
      expect((await storage.read()).single.ownerKey, isNotNull);
      final before = await storage.day();
      expect(before.knownCalories, 123);
      expect(_savedItem(before)['food'], 'Cooked food');

      await (storage.db.update(
        storage.db.foods,
      )..where((row) => row.id.equals(1))).write(
        const FoodsCompanion(
          name: Value('Later catalog name'),
          calories: Value(999),
        ),
      );
      final rows = await storage.read();
      expect(rows.single.foodsById[1]!.name, 'Later catalog name');
      final after = assembleCoachNutritionDays(rows).single;
      expect(after.toJson(), before.toJson());
    },
  );

  test(
    'stored modern corruption cannot reuse complete mask and zero columns',
    () async {
      final storage = _storage();
      await storage.save([modernDiaryItem()]);
      for (final raw in <String?>['{invalid', null]) {
        await (storage.db.update(
          storage.db.mealItems,
        )..where((row) => row.id.equals(1))).write(
          MealItemsCompanion(
            calories: const Value(0),
            protein: const Value(0),
            carbs: const Value(0),
            fats: const Value(0),
            sodium: const Value(0),
            foodEvidenceJson: Value(raw),
          ),
        );
        final rows = await storage.read();
        expect(rows.single.items.single.nutrientEvidenceMask, isPositive);
        final day = assembleCoachNutritionDays(rows).single;
        expect(day.knownTotals, isEmpty);
        expect(day.knownCalories, isNull);
        expect(day.toJson()['totals'], isEmpty);
        expect(_savedItem(day), {'itemId': 1, 'food': 'historical-food'});
      }
    },
  );

  test(
    'stored calorie-only has no catalog food in the Coach readback',
    () async {
      final storage = _storage();
      await storage.save([calorieOnlyDiaryItem()]);
      final day = await storage.day();
      expect(_savedItem(day), {
        'itemId': 1,
        'entryType': 'quick_add',
        'caloriesKcal': 1905.0,
      });
      expect(day.toJson()['totals'], {'caloriesKcal': 1905.0});
      expect(day.knownTotals, {'caloriesKcal'});
    },
  );

  test(
    'stored day key determines history even when timestamp date differs',
    () async {
      final storage = _storage();
      await storage.save([modernDiaryItem()]);
      await (storage.db.update(storage.db.meals)
            ..where((row) => row.id.equals(1)))
          .write(MealsCompanion(date: Value(DateTime.utc(2026, 10, 7))));
      final day = await storage.day();
      expect(day.day, '2026-10-06');
      expect(day.knownCalories, 123);
    },
  );
}
