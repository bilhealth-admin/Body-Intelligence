part of 'coach_food_commit_test.dart';

void _foodJournalCases() {
  test(
    'second-food database failure rolls back foods, items, bucket and journal together',
    () async {
      final f = _fixture();
      await f.db.customStatement(
        '''CREATE TRIGGER fail_second_food BEFORE INSERT ON meal_items
      WHEN (SELECT COUNT(*) FROM meal_items) >= 1
      BEGIN SELECT RAISE(ABORT, 'second item rejected'); END''',
      );
      await expectLater(
        f.commit('atomic', [_portion(), _portion(name: 'Second')]),
        throwsA(isA<Exception>()),
      );
      expect(await f.active(), isEmpty);
      expect(await f.db.select(f.db.meals).get(), isEmpty);
      expect(await f.db.select(f.db.foods).get(), isEmpty);
      expect(await f.db.select(f.db.preferences).get(), isEmpty);
      await f.db.customStatement('DROP TRIGGER fail_second_food');
      final retry = await f.commit('atomic', [
        _portion(),
        _portion(name: 'Second'),
      ]);
      expect(retry.after, hasLength(2));
      expect(retry.replayed, false);
    },
  );

  test(
    'unexpected committed nutrient readback rolls back before journal success',
    () async {
      final f = _fixture();
      await f.db.customStatement(
        '''CREATE TRIGGER alter_food AFTER INSERT ON meal_items
      BEGIN UPDATE meal_items SET calories = calories + 1 WHERE id = NEW.id; END''',
      );
      await expectLater(
        f.commit('readback', [_portion()]),
        _conflict(CoachMealConflictReason.invalidEvidence),
      );
      expect(await f.active(), isEmpty);
      expect(await f.db.select(f.db.foods).get(), isEmpty);
      expect(await f.db.select(f.db.preferences).get(), isEmpty);
    },
  );

  test(
    'concurrent same-operation calls create one batch and reject changed arguments',
    () async {
      final f = _fixture();
      final portions = [_portion(), _portion(name: 'Other')];
      final results = await Future.wait([
        f.commit('concurrent', portions),
        f.commit('concurrent', portions),
      ]);
      expect(results.where((result) => result.replayed), hasLength(1));
      expect(await f.active(), hasLength(2));
      await expectLater(
        f.commit('concurrent', [_portion(grams: 90)]),
        _conflict(CoachMealConflictReason.operationMismatch),
      );
      expect(await f.active(), hasLength(2));
    },
  );

  test(
    'batch Undo preserves older meal items and replay never resurrects its foods',
    () async {
      final f = _fixture();
      final older = await f.commit('older', [_portion(name: 'Older')]);
      final current = await f.commit('new', [
        _portion(name: 'New one'),
        _portion(name: 'New two'),
      ]);
      expect(current.after.first.meal.id, older.after.single.meal.id);
      final undone = await f.undo(current);
      expect(undone.state, CoachMealResultState.undone);
      expect((await f.active()).single.uuid, older.after.single.item.uuid);
      expect((await f.undo(current)).replayed, true);
      final replay = await f.commit('new', [
        _portion(name: 'New one'),
        _portion(name: 'New two'),
      ]);
      expect(replay.state, CoachMealResultState.undone);
      expect(await f.active(), hasLength(1));
    },
  );

  test(
    'later quantity edit blocks stale replacement and stale batch Undo',
    () async {
      final f = _fixture();
      final original = await f.commit('original', [_portion()]);
      final item = original.after.single.item;
      await f.meals.updateMealItem(id: item.id, quantity: 70);
      await expectLater(
        f.meals.commitCoachMeal(
          command: CoachMealCommand.replaceFood(
            operationId: 'stale',
            expected: CoachMealItemVersion.fromItem(item),
            replacement: _portion(name: 'Wrong overwrite'),
          ),
          scope: f.scope(),
        ),
        _conflict(CoachMealConflictReason.staleItem),
      );
      await expectLater(
        f.undo(original),
        _conflict(CoachMealConflictReason.staleItem),
      );
      expect((await f.active()).single.quantity, 70);
    },
  );

  test(
    'fixed per-user source accepts its opaque owner and rejects another user before writes',
    () async {
      final f = _fixture();
      final owner = LocalDatabaseScope.keyForOwner('food-owner');
      final result = await f.commit('fixed', [_portion(fixedOwner: owner)]);
      expect(
        MealFoodEvidence.read(
          result.after.single.item,
          ownerKey: owner,
        ).isValid,
        true,
      );
      await expectLater(
        f.commit('wrong-fixed', [
          _portion(fixedOwner: LocalDatabaseScope.keyForOwner('other')),
        ]),
        _conflict(CoachMealConflictReason.ownerChanged),
      );
      expect(await f.active(), hasLength(1));
      expect(await f.db.select(f.db.preferences).get(), hasLength(1));
    },
  );

  test(
    'every batch async owner boundary is atomic or reports an already durable commit',
    () async {
      final probe = _FoodFixture();
      var boundaries = 0;
      final portions = [_portion(), _portion(name: 'Second')];
      await probe.meals.commitCoachMeal(
        command: probe.command('probe', portions),
        scope: CoachMealOwnerScope(
          ownerId: 'food-owner',
          isCurrent: () {
            boundaries++;
            return true;
          },
        ),
      );
      await probe.db.close();
      expect(boundaries, greaterThan(30));
      var rolledBack = 0;
      var durable = 0;
      for (var stop = 1; stop <= boundaries; stop++) {
        final f = _FoodFixture();
        try {
          var checks = 0;
          try {
            await f.meals.commitCoachMeal(
              command: f.command('scope-$stop', portions),
              scope: CoachMealOwnerScope(
                ownerId: 'food-owner',
                isCurrent: () => ++checks < stop,
              ),
            );
            fail('Owner changed at boundary $stop');
          } on CoachMealConflict catch (error) {
            expect(error.reason, CoachMealConflictReason.ownerChanged);
            if (error.committed) {
              durable++;
              expect(await f.active(), hasLength(2));
              expect(await f.db.select(f.db.preferences).get(), hasLength(1));
            } else {
              rolledBack++;
              expect(await f.active(), isEmpty);
              expect(await f.db.select(f.db.foods).get(), isEmpty);
              expect(await f.db.select(f.db.meals).get(), isEmpty);
              expect(await f.db.select(f.db.preferences).get(), isEmpty);
            }
          }
        } finally {
          await f.db.close();
        }
      }
      expect(rolledBack, greaterThan(0));
      expect(durable, greaterThan(0));
      expect(rolledBack + durable, boundaries);
    },
  );
}
