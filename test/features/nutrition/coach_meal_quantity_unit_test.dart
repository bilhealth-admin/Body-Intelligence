import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final unit in ['entry', 'ml', 'serving', 'item', 'cup']) {
    test(
      'gram command rejects $unit without changing item or journal',
      () async {
        final fixture = await _seed(unit);
        final command = fixture.command(80, grams: true);
        final ledgerBefore = await DailyLogRepository(
          fixture.db,
        ).readLedger(_day);
        await expectLater(
          fixture.meals.commitCoachMeal(command: command, scope: fixture.scope),
          throwsA(
            isA<CoachMealConflict>().having(
              (error) => error.reason,
              'reason',
              CoachMealConflictReason.invalidEvidence,
            ),
          ),
        );
        expect(await fixture.meals.getMealItem(fixture.item.id), fixture.item);
        expect(
          await fixture.meals.readCoachMealOperation(
            operationId: command.operationId,
            scope: fixture.scope,
          ),
          isNull,
        );
        final ledger = await DailyLogRepository(fixture.db).readLedger(_day);
        expect(ledger.calories, ledgerBefore.calories);
        expect(ledger.protein, ledgerBefore.protein);
        expect(ledger.carbohydrates, ledgerBefore.carbohydrates);
        expect(ledger.fat, ledgerBefore.fat);
        expect(await fixture.db.select(fixture.db.meals).get(), hasLength(1));
      },
    );

    test('explicit stored-unit edits still work for $unit and Undo', () async {
      final fixture = await _seed(unit);
      final command = fixture.command(1, grams: false);
      expect(command.arguments.containsKey('quantityUnit'), isFalse);
      final result = await fixture.meals.commitCoachMeal(
        command: command,
        scope: fixture.scope,
      );
      final after = result.after.single.item;
      expect(after.quantity, 1);
      expect(after.servingUnitSnapshot, unit);
      expect(after.calories, fixture.item.calories / 2);
      expect(after.nutrientEvidenceMask, fixture.item.nutrientEvidenceMask);
      final undo = await fixture.meals.undoCoachMeal(
        operationId: result.operationId,
        toolId: result.toolId,
        argumentsDigest: result.argumentsDigest,
        scope: fixture.scope,
      );
      expect(undo.state, CoachMealResultState.undone);
      final restored = undo.current.single!.item;
      expect(restored.quantity, fixture.item.quantity);
      expect(restored.calories, fixture.item.calories);
      expect(restored.servingUnitSnapshot, unit);
    });
  }

  test('gram quantity freezes unit meaning in operation digest', () async {
    final fixture = await _seed('g');
    final grams = fixture.command(1, grams: true);
    final stored = fixture.command(1, grams: false);
    expect(grams.arguments['quantityUnit'], 'g');
    expect(grams.argumentsDigest, isNot(stored.argumentsDigest));
    final result = await fixture.meals.commitCoachMeal(
      command: grams,
      scope: fixture.scope,
    );
    expect(result.after.single.item.quantity, 1);
    expect(result.after.single.item.calories, fixture.item.calories / 2);
    final replay = await fixture.meals.commitCoachMeal(
      command: grams,
      scope: fixture.scope,
    );
    expect(replay.replayed, isTrue);
    expect(replay.after.single.item, result.after.single.item);
    await expectLater(
      fixture.meals.commitCoachMeal(command: stored, scope: fixture.scope),
      throwsA(
        isA<CoachMealConflict>().having(
          (error) => error.reason,
          'reason',
          CoachMealConflictReason.operationMismatch,
        ),
      ),
    );
  });

  test('gram edit never reads a newer catalog conversion', () async {
    final fixture = await _seed('ml');
    await (fixture.db.update(
      fixture.db.foods,
    )..where((row) => row.id.equals(fixture.item.foodId))).write(
      const FoodsCompanion(
        servingUnit: Value('g'),
        servingSize: Value(100),
        calories: Value(1),
      ),
    );
    await expectLater(
      fixture.meals.commitCoachMeal(
        command: fixture.command(100, grams: true),
        scope: fixture.scope,
      ),
      throwsA(isA<CoachMealConflict>()),
    );
    expect(await fixture.meals.getMealItem(fixture.item.id), fixture.item);
  });
}

final _day = DateTime(2026, 10, 6);

Future<_QuantityFixture> _seed(String unit) async {
  final db = AppDatabase.forTesting(
    NativeDatabase.memory(),
    localOwnerId: 'quantity-owner',
  );
  addTearDown(db.close);
  final meals = MealRepository(db);
  final food = await FoodRepository(db).addFood(
    name: 'Explicit unit $unit',
    category: 'fixture',
    servingSize: 1,
    servingUnit: unit,
    calories: 50,
    protein: 2,
    carbs: 3,
    fats: 1,
    source: 'label',
  );
  final meal = await meals.createMeal(date: _day, name: 'lunch', type: 'lunch');
  await meals.addMealItem(mealId: meal, foodId: food, quantity: 2);
  final item = await db.select(db.mealItems).getSingle();
  return _QuantityFixture(db, meals, item);
}

final class _QuantityFixture {
  _QuantityFixture(this.db, this.meals, this.item);
  final AppDatabase db;
  final MealRepository meals;
  final MealItem item;
  final scope = CoachMealOwnerScope(
    ownerId: 'quantity-owner',
    isCurrent: () => true,
  );
  CoachMealCommand command(double quantity, {required bool grams}) =>
      CoachMealCommand.updateQuantity(
        operationId: 'quantity-unit-command',
        expected: CoachMealItemVersion.fromItem(item),
        quantity: quantity,
        quantityInGrams: grams,
      );
}
