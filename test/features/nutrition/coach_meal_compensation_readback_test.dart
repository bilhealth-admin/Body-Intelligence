import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in [
    'quick',
    'quantity',
    'remove',
    'move',
    'parent',
    'bucket',
  ]) {
    test('meal Undo verifies the complete $kind compensation readback', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final meals = MealRepository(database);
      final scope = CoachMealOwnerScope(ownerId: null, isCurrent: () => true);
      final day = DateTime(2026, 10, 6);
      final food = await FoodRepository(database).addFood(
        name: 'Existing label food',
        category: 'grain',
        servingSize: 100,
        servingUnit: 'g',
        calories: 380,
        protein: 13,
        carbs: 68,
        fats: 7,
        source: 'label',
      );
      final meal = await meals.createMeal(
        date: day,
        name: 'breakfast',
        type: 'breakfast',
      );
      await meals.addMealItem(mealId: meal, foodId: food, quantity: 100);
      final original = await database.select(database.mealItems).getSingle();
      final expected = CoachMealItemVersion.fromItem(original);
      final command = switch (kind) {
        'quantity' || 'parent' => CoachMealCommand.updateQuantity(
          operationId: 'readback-$kind',
          expected: expected,
          quantity: 150,
        ),
        'remove' => CoachMealCommand.deleteItem(
          operationId: 'readback-$kind',
          expected: expected,
        ),
        'move' => CoachMealCommand.moveItem(
          operationId: 'readback-$kind',
          expected: expected,
          mealType: 'dinner',
        ),
        _ => CoachMealCommand.quickMacros(
          operationId: 'readback-$kind',
          date: day,
          mealType: 'lunch',
          calories: 1905,
        ),
      };
      final saved = await meals.commitCoachMeal(command: command, scope: scope);
      final savedItems = await database.select(database.mealItems).get();
      final savedMeals = await database.select(database.meals).get();
      final savedJournals = await database.select(database.preferences).get();
      final itemId = saved.after.single.item.id;
      final bucketId = saved.after.single.meal.id;
      final trigger = switch (kind) {
        'parent' =>
          'CREATE TRIGGER alter_parent AFTER UPDATE ON meal_items '
              'WHEN NEW.id = $itemId BEGIN UPDATE meals SET name = \'Unexpected parent change\' '
              'WHERE id = $bucketId; END',
        'bucket' =>
          'CREATE TRIGGER keep_bucket AFTER UPDATE ON meals '
              'WHEN NEW.id = $bucketId AND NEW.deleted_at IS NOT NULL '
              'BEGIN UPDATE meals SET deleted_at = NULL WHERE id = $bucketId; END',
        _ =>
          'CREATE TRIGGER alter_item AFTER UPDATE ON meal_items '
              'WHEN NEW.id = $itemId AND NEW.calories = ${original.calories} '
              'OR NEW.id = $itemId AND NEW.calories = 1905 '
              'BEGIN UPDATE meal_items SET calories = calories + 1 WHERE id = $itemId; END',
      };
      await database.customStatement(trigger);
      await expectLater(
        meals.undoCoachMeal(
          operationId: saved.operationId,
          toolId: saved.toolId,
          argumentsDigest: saved.argumentsDigest,
          scope: scope,
        ),
        throwsA(
          isA<CoachMealConflict>()
              .having(
                (error) => error.reason,
                'reason',
                CoachMealConflictReason.readbackUnavailable,
              )
              .having((error) => error.committed, 'committed', isFalse),
        ),
      );
      expect(await database.select(database.mealItems).get(), savedItems);
      expect(await database.select(database.meals).get(), savedMeals);
      expect(await database.select(database.preferences).get(), savedJournals);
      final readback = await meals.readCoachMealOperation(
        operationId: saved.operationId,
        scope: scope,
      );
      expect(readback!.state, CoachMealResultState.committed);
      expect(readback.canUndo, isTrue);
      expect(readback.undoneAt, isNull);
    });
  }
}
