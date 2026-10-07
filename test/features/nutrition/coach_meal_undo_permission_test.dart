import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in ['quick', 'quantity', 'remove', 'move']) {
    for (final boundary in [1, 2, 3, 4]) {
      test(
        '$kind Undo revocation boundary $boundary leaves rows and journal intact',
        () async {
          final database = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(database.close);
          final meals = MealRepository(database);
          final scope = CoachMealOwnerScope(
            ownerId: null,
            isCurrent: () => true,
          );
          final first = await meals.commitCoachMeal(
            command: CoachMealCommand.quickMacros(
              operationId: 'original-quick',
              date: DateTime(2026, 10, 6),
              mealType: 'lunch',
              calories: 1905,
            ),
            scope: scope,
          );
          final expected = CoachMealItemVersion.fromItem(
            first.after.single.item,
          );
          final command = switch (kind) {
            'quantity' => CoachMealCommand.updateQuantity(
              operationId: 'second-quantity',
              expected: expected,
              quantity: 2,
            ),
            'remove' => CoachMealCommand.deleteItem(
              operationId: 'second-remove',
              expected: expected,
            ),
            'move' => CoachMealCommand.moveItem(
              operationId: 'second-move',
              expected: expected,
              mealType: 'dinner',
            ),
            _ => null,
          };
          final saved = command == null
              ? first
              : await meals.commitCoachMeal(command: command, scope: scope);
          final itemsBefore = await database.select(database.mealItems).get();
          final mealsBefore = await database.select(database.meals).get();
          final journalBefore = await database
              .select(database.preferences)
              .get();
          var calls = 0;
          await expectLater(
            meals.undoCoachMeal(
              operationId: saved.operationId,
              toolId: saved.toolId,
              argumentsDigest: saved.argumentsDigest,
              scope: scope,
              checkWritePermission: () {
                if (++calls == boundary) throw StateError('permission_revoked');
              },
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'reason',
                'permission_revoked',
              ),
            ),
          );
          expect(calls, boundary);
          expect(await database.select(database.mealItems).get(), itemsBefore);
          expect(await database.select(database.meals).get(), mealsBefore);
          expect(
            await database.select(database.preferences).get(),
            journalBefore,
          );
          final read = await meals.readCoachMealOperation(
            operationId: saved.operationId,
            scope: scope,
          );
          expect(read!.canUndo, isTrue);
          final undone = await meals.undoCoachMeal(
            operationId: saved.operationId,
            toolId: saved.toolId,
            argumentsDigest: saved.argumentsDigest,
            scope: scope,
            checkWritePermission: () {},
          );
          expect(undone.state, CoachMealResultState.undone);
          expect(undone.undoneAt, isNotNull);
        },
      );
    }
  }
}
