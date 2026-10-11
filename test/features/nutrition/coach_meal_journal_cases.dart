part of 'coach_meal_commit_boundary_test.dart';

final _coachDay = DateTime(2026, 10, 6);

final class _MealFixture {
  _MealFixture()
    : database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'owner-a',
      ) {
    meals = MealRepository(database);
  }

  final AppDatabase database;
  late final MealRepository meals;

  CoachMealOwnerScope scope() =>
      CoachMealOwnerScope(ownerId: 'owner-a', isCurrent: () => true);

  CoachMealCommand macros(String operation, {double calories = 1905}) =>
      CoachMealCommand.quickMacros(
        operationId: operation,
        date: _coachDay,
        mealType: 'lunch',
        calories: calories,
      );

  Future<CoachMealCommit> commit(CoachMealCommand command) =>
      meals.commitCoachMeal(command: command, scope: scope());

  Future<CoachMealCommit> undo(CoachMealCommit committed) =>
      meals.undoCoachMeal(
        operationId: committed.operationId,
        toolId: committed.toolId,
        argumentsDigest: committed.argumentsDigest,
        scope: scope(),
      );

  Future<List<MealItem>> activeItems() => (database.select(
    database.mealItems,
  )..where((row) => row.deletedAt.isNull())).get();

  Future<MealItem> seed({int? mealId, String type = 'lunch'}) async {
    final food = await FoodRepository(database).addFood(
      name: 'Older label entry',
      category: 'grain',
      servingSize: 100,
      servingUnit: 'g',
      calories: 380,
      protein: 13,
      carbs: 68,
      fats: 7,
      source: 'label',
    );
    final target =
        mealId ??
        await meals.createMeal(date: _coachDay, name: type, type: type);
    await meals.addMealItem(mealId: target, foodId: food, quantity: 100);
    return (await activeItems()).last;
  }
}

Matcher _mealConflict(CoachMealConflictReason reason) => throwsA(
  isA<CoachMealConflict>().having((error) => error.reason, 'reason', reason),
);

void _coachMealJournalCases() {
  late _MealFixture fixture;
  setUp(() => fixture = _MealFixture());
  tearDown(() => fixture.database.close());

  test(
    '1905 calorie-only command has unknown macros in stored item, receipt and totals',
    () async {
      final result = await fixture.commit(fixture.macros('calorie-only'));
      final item = result.after.single.item;
      final receipt = result.after.single.toReceiptPayload();
      expect(item.calories, 1905);
      expect(item.protein, 0);
      expect(
        item.nutrientEvidenceMask,
        NutrientEvidenceMask.bit(TrackedNutrient.calories),
      );
      expect(receipt['calories'], 1905);
      for (final key in [
        'protein',
        'carbohydrates',
        'fat',
        'fiber',
        'sodium_mg',
        'potassium_mg',
      ]) {
        expect(receipt[key], isNull, reason: key);
      }
      expect(receipt['source'], 'quick_add');
      expect(receipt['source_verified'], isFalse);
      expect(
        (await fixture.database.select(fixture.database.foods).get())
            .single
            .category,
        'quick_add',
      );
      final ledger = await DailyLogRepository(
        fixture.database,
      ).readLedger(_coachDay);
      expect(ledger.calories, 1905);
      expect(ledger.protein, isNull);
      expect(ledger.carbohydrates, isNull);
      expect(ledger.fat, isNull);
      expect(result.state, CoachMealResultState.committed);
      expect(result.replayed, isFalse);
      expect(result.current.single!.item, item);
    },
  );

  test(
    'Undo add touches only its item and preserves a reused bucket and older food',
    () async {
      final older = await fixture.seed();
      final bucket =
          (await fixture.database.select(fixture.database.meals).get()).single;
      final result = await fixture.commit(fixture.macros('reused-bucket'));
      final undone = await fixture.undo(result);
      expect(await fixture.activeItems(), [older]);
      expect(await fixture.meals.getMealItem(older.id), older);
      expect(
        (await fixture.database.select(fixture.database.meals).get()).single,
        bucket,
      );
      expect(undone.state, CoachMealResultState.undone);
      expect(undone.current.single!.item.deletedAt, isNotNull);
      expect(
        undone.current.single!.item.revision,
        result.after.single.item.revision + 1,
      );
    },
  );

  test(
    'Undo removes a newly created empty bucket but preserves later unrelated food',
    () async {
      final first = await fixture.commit(fixture.macros('new-bucket'));
      await fixture.undo(first);
      expect(await fixture.meals.watchMealsForDate(_coachDay).first, isEmpty);
      final second = await fixture.commit(
        fixture.macros('new-bucket-with-later-item'),
      );
      final later = await fixture.seed(mealId: second.after.single.meal.id);
      await fixture.undo(second);
      final remaining = await fixture.meals.watchMealsForDate(_coachDay).first;
      expect(remaining, hasLength(1));
      expect(remaining.single.items, [later]);
      expect(remaining.single.meal.id, second.after.single.meal.id);
    },
  );

  test(
    'same operation after repository restart reads committed rows and a changed command conflicts',
    () async {
      final command = fixture.macros('retry');
      final first = await fixture.commit(command);
      final restarted = MealRepository(fixture.database);
      final replay = await restarted.commitCoachMeal(
        command: command,
        scope: fixture.scope(),
      );
      expect(replay.replayed, isTrue);
      expect(replay.after.single.item, first.after.single.item);
      expect(replay.committedAt, first.committedAt);
      expect(await fixture.activeItems(), hasLength(1));
      await expectLater(
        fixture.commit(fixture.macros('retry', calories: 1906)),
        _mealConflict(CoachMealConflictReason.operationMismatch),
      );
      expect(await fixture.activeItems(), [first.after.single.item]);
      await fixture.commit(fixture.macros('deliberate-equal-new-proposal'));
      expect(await fixture.activeItems(), hasLength(2));
    },
  );

  test(
    'concurrent same-operation calls write one item and one durable journal',
    () async {
      final command = fixture.macros('concurrent');
      final results = await Future.wait([
        fixture.commit(command),
        fixture.commit(command),
      ]);
      expect(results.where((result) => !result.replayed), hasLength(1));
      expect(
        results.map((result) => result.after.single.item.id).toSet(),
        hasLength(1),
      );
      expect(await fixture.activeItems(), hasLength(1));
      final journals = await fixture.database
          .select(fixture.database.preferences)
          .get();
      expect(
        journals.where((row) => row.key.startsWith('coachMealOperationV1.')),
        hasLength(1),
      );
    },
  );

  test(
    'duplicate Undo and retry after Undo do not reapply or increment revisions',
    () async {
      final command = fixture.macros('one-undo');
      final result = await fixture.commit(command);
      final undone = await fixture.undo(result);
      final secondUndo = await fixture.undo(result);
      final retry = await fixture.commit(command);
      expect(secondUndo.replayed, isTrue);
      expect(secondUndo.undoneAt, undone.undoneAt);
      expect(secondUndo.current.single!.item, undone.current.single!.item);
      expect(retry.state, CoachMealResultState.undone);
      expect(retry.current.single!.item, undone.current.single!.item);
      expect(await fixture.activeItems(), isEmpty);
      expect(
        await fixture.database.select(fixture.database.mealItems).get(),
        hasLength(1),
      );
    },
  );

  test(
    'a later quantity edit rejects stale Undo and retry discloses modified state',
    () async {
      final command = fixture.macros('later-edit');
      final result = await fixture.commit(command);
      final id = result.after.single.item.id;
      await fixture.meals.updateMealItem(id: id, quantity: 2);
      final later = await fixture.meals.getMealItem(id);
      await expectLater(
        fixture.undo(result),
        _mealConflict(CoachMealConflictReason.staleItem),
      );
      expect(await fixture.meals.getMealItem(id), later);
      final retry = await fixture.commit(command);
      expect(retry.state, CoachMealResultState.modified);
      expect(retry.after.single.item, result.after.single.item);
      expect(retry.current.single!.item, later);
      expect(retry.canUndo, isFalse);
    },
  );

  test(
    'update delete and move restore immutable snapshots and original positions',
    () async {
      final original = await fixture.seed(type: 'breakfast');
      var current = original;
      final update = await fixture.commit(
        CoachMealCommand.updateQuantity(
          operationId: 'update',
          expected: CoachMealItemVersion.fromItem(current),
          quantity: 150,
        ),
      );
      expect(update.after.single.item.calories, original.calories * 1.5);
      await (fixture.database.update(
        fixture.database.foods,
      )..where((row) => row.id.equals(original.foodId))).write(
        const FoodsCompanion(
          calories: Value(999),
          source: Value('changed_catalog'),
        ),
      );
      final restoredUpdate = await fixture.undo(update);
      current = restoredUpdate.current.single!.item;
      expect(current.calories, original.calories);
      expect(current.foodSourceSnapshot, original.foodSourceSnapshot);
      expect(current.quantity, original.quantity);

      final move = await fixture.commit(
        CoachMealCommand.moveItem(
          operationId: 'move',
          expected: CoachMealItemVersion.fromItem(current),
          mealType: 'dinner',
        ),
      );
      expect(move.after.single.meal.type, 'dinner');
      final restoredMove = await fixture.undo(move);
      current = restoredMove.current.single!.item;
      expect(current.mealId, original.mealId);
      expect(current.position, original.position);
      expect(
        (await fixture.meals.watchMealsForDate(_coachDay).first).map(
          (meal) => meal.meal.type,
        ),
        ['breakfast'],
      );

      final remove = await fixture.commit(
        CoachMealCommand.deleteItem(
          operationId: 'delete',
          expected: CoachMealItemVersion.fromItem(current),
        ),
      );
      expect(remove.after.single.item.deletedAt, isNotNull);
      final restoredDelete = await fixture.undo(remove);
      expect(restoredDelete.current.single!.item.deletedAt, isNull);
      expect(restoredDelete.current.single!.item.calories, original.calories);
      expect(
        restoredDelete.current.single!.item.foodSourceSnapshot,
        original.foodSourceSnapshot,
      );
    },
  );

  test('stale UUID or revision is rejected before item mutation', () async {
    final original = await fixture.seed();
    for (final version in [
      CoachMealItemVersion(
        id: original.id,
        uuid: 'another-uuid',
        revision: original.revision,
      ),
      CoachMealItemVersion(
        id: original.id,
        uuid: original.uuid,
        revision: original.revision + 1,
      ),
    ]) {
      await expectLater(
        fixture.commit(
          CoachMealCommand.updateQuantity(
            operationId: 'stale-${version.uuid}',
            expected: version,
            quantity: 50,
          ),
        ),
        _mealConflict(CoachMealConflictReason.staleItem),
      );
    }
    expect(await fixture.meals.getMealItem(original.id), original);
    final preferences = await fixture.database
        .select(fixture.database.preferences)
        .get();
    expect(preferences, hasLength(1));
    expect(preferences.single.key, firstMealCelebrationPreferenceKey);
    expect(preferences.single.value, 'ready');
  });

  test(
    'closed day blocks all four commands and Undo without changing its ledger',
    () async {
      final original = await fixture.seed();
      final committed = await fixture.commit(fixture.macros('before-close'));
      final daily = DailyLogRepository(fixture.database);
      await daily.startDay(_coachDay);
      await daily.closeDay(_coachDay);
      final log = await fixture.database
          .select(fixture.database.dailyLogs)
          .getSingle();
      final items = await fixture.activeItems();
      final commands = [
        fixture.macros('closed-add'),
        CoachMealCommand.updateQuantity(
          operationId: 'closed-update',
          expected: CoachMealItemVersion.fromItem(original),
          quantity: 50,
        ),
        CoachMealCommand.deleteItem(
          operationId: 'closed-delete',
          expected: CoachMealItemVersion.fromItem(original),
        ),
        CoachMealCommand.moveItem(
          operationId: 'closed-move',
          expected: CoachMealItemVersion.fromItem(original),
          mealType: 'dinner',
        ),
      ];
      for (final command in commands) {
        await expectLater(
          fixture.commit(command),
          _mealConflict(CoachMealConflictReason.closedDay),
        );
      }
      await expectLater(
        fixture.undo(committed),
        _mealConflict(CoachMealConflictReason.closedDay),
      );
      expect(await fixture.activeItems(), items);
      expect(
        await fixture.database.select(fixture.database.dailyLogs).getSingle(),
        log,
      );
      expect(
        (await daily.readLedger(_coachDay)).state,
        DayLifecycleState.closed,
      );
    },
  );

  test(
    'journal write failure rolls back its food, meal and item atomically',
    () async {
      await fixture.database.customStatement('''
      CREATE TEMP TRIGGER reject_coach_journal BEFORE INSERT ON preferences
      WHEN NEW.key LIKE 'coachMealOperationV1.%'
      BEGIN SELECT RAISE(ABORT, 'test journal failure'); END
    ''');
      await expectLater(
        fixture.commit(fixture.macros('journal-fails')),
        throwsA(isA<Exception>()),
      );
      expect(
        await fixture.database.select(fixture.database.foods).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.meals).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.mealItems).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.preferences).get(),
        isEmpty,
      );
    },
  );

  test(
    'Undo journal failure rolls compensation back and preserves original committed rows',
    () async {
      final result = await fixture.commit(fixture.macros('undo-journal-fails'));
      final journals = await fixture.database
          .select(fixture.database.preferences)
          .get();
      await fixture.database.customStatement('''
      CREATE TEMP TRIGGER reject_undo_journal BEFORE UPDATE ON preferences
      WHEN NEW.key LIKE 'coachMealOperationV1.%'
      BEGIN SELECT RAISE(ABORT, 'test undo journal failure'); END
    ''');
      await expectLater(fixture.undo(result), throwsA(isA<Exception>()));
      expect(await fixture.activeItems(), [result.after.single.item]);
      expect(
        await fixture.database.select(fixture.database.preferences).get(),
        journals,
      );
      expect(
        (await fixture.meals.watchMealsForDate(_coachDay).first).single.meal,
        result.after.single.meal,
      );
    },
  );

  test(
    'nested command arguments are immutable and cannot change the retry digest',
    () async {
      final original = await fixture.seed();
      final command = CoachMealCommand.updateQuantity(
        operationId: 'immutable',
        expected: CoachMealItemVersion.fromItem(original),
        quantity: 50,
      );
      final digest = command.argumentsDigest;
      expect(
        () => (command.arguments['expected']! as Map)['revision'] = 99,
        throwsUnsupportedError,
      );
      expect(() => command.arguments['quantity'] = 100, throwsUnsupportedError);
      expect(command.argumentsDigest, digest);
    },
  );
}
