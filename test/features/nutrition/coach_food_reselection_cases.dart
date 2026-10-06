part of 'coach_food_commit_test.dart';

void _foodReselectionCases() {
  final nextDay = DateTime(2026, 10, 7, 12);
  test(
    'ordinary diary selection keeps thirteen nutrients and source evidence',
    () async {
      final f = _fixture();
      final first = (await f.commit('reselect-original', [
        _portion(),
      ])).after.single;
      await f.meals.addReviewedMealItemsAtomically(
        date: nextDay,
        mealType: 'lunch',
        items: [(foodId: first.item.foodId, quantity: 75.0)],
      );
      final saved = (await f.meals.watchMealsForDate(nextDay).first).single;
      expect(saved.ownerKey, LocalDatabaseScope.keyForOwner(f.db.localOwnerId));
      final item = saved.items.single;
      final evidence = MealFoodEvidence.read(item, ownerKey: saved.ownerKey);
      expect(evidence.state, MealFoodEvidenceState.valid);
      expect(evidence.fullValue(FoodNutrient.calories), 120);
      expect(evidence.fullValue(FoodNutrient.iron), 1.5);
      expect(evidence.fullValue(FoodNutrient.vitaminC), isNull);
      expect(evidence.portion!.food.toJson(), _portion().food.toJson());
      expect(
        evidence.portion!.quantity.evidence.kind,
        CoachFoodQuantityKind.userDeclared,
      );
      expect(evidence.portion!.quantity.evidence.confidence, isNull);
      expect(evidence.portion!.identityConfidence, isNull);
      expect(item.foodVerifiedSnapshot, false);
      expect(
        (await f.meals.watchAll().first).map((meal) => meal.ownerKey),
        everyElement(saved.ownerKey),
      );
    },
  );

  test(
    'meal builder keeps an unknown food alongside a known zero food',
    () async {
      final f = _fixture();
      final first = await f.commit('builder-original', [
        _portion(name: 'Unknown', nutrients: {}),
        _portion(
          name: 'Known zero',
          nutrients: {FoodNutrient.calories: 0, FoodNutrient.iron: 0},
        ),
      ]);
      await f.meals.createMealFromDraft(
        date: nextDay,
        draft: MealBuilderDraft(
          name: 'Two reviewed foods',
          mealType: 'lunch',
          items: [
            for (var i = 0; i < 2; i++)
              MealBuilderItemDraft(
                foodId: first.after[i].item.foodId,
                quantityGrams: 80,
                position: i + 1,
              ),
          ],
        ),
      );
      final saved = (await f.meals.watchMealsForDate(nextDay).first).single;
      expect(saved.items, hasLength(2));
      final unknown = MealFoodEvidence.read(saved.items[0]);
      final zero = MealFoodEvidence.read(saved.items[1]);
      expect(unknown.state, MealFoodEvidenceState.valid);
      expect(unknown.values.values, everyElement(isNull));
      expect(zero.fullValue(FoodNutrient.calories), 0);
      expect(zero.fullValue(FoodNutrient.iron), 0);
      expect(zero.fullValue(FoodNutrient.protein), isNull);
      expect(
        (await DailyLogRepository(f.db).readLedger(nextDay)).calories,
        isNull,
      );
    },
  );

  test(
    'invalid catalog basis cannot be reselected as legacy numeric nutrition',
    () async {
      final f = _fixture();
      final first = (await f.commit('reselect-corrupt', [
        _portion(),
      ])).after.single;
      await (f.db.update(f.db.foods)
            ..where((row) => row.id.equals(first.item.foodId)))
          .write(const FoodsCompanion(foodEvidenceJson: Value('{invalid')));
      await expectLater(
        f.meals.addReviewedMealItemsAtomically(
          date: nextDay,
          mealType: 'lunch',
          items: [(foodId: first.item.foodId, quantity: 75.0)],
        ),
        _conflict(CoachMealConflictReason.invalidEvidence),
      );
      expect(await f.meals.watchMealsForDate(nextDay).first, isEmpty);
      expect(await f.active(), [first.item]);
    },
  );

  test('readback corruption rolls back ordinary Food V2 reselection', () async {
    final f = _fixture();
    final first = (await f.commit('reselect-readback', [
      _portion(),
    ])).after.single;
    await f.db.customStatement('''
      CREATE TRIGGER corrupt_reselected AFTER INSERT ON meal_items
      BEGIN UPDATE meal_items SET protein = 999 WHERE id = NEW.id; END
    ''');
    await expectLater(
      f.meals.addReviewedMealItemsAtomically(
        date: nextDay,
        mealType: 'lunch',
        items: [(foodId: first.item.foodId, quantity: 75.0)],
      ),
      _conflict(CoachMealConflictReason.readbackUnavailable),
    );
    expect(await f.meals.watchMealsForDate(nextDay).first, isEmpty);
    expect(await f.active(), [first.item]);
  });

  test(
    'foreign fixed-owner basis cannot be reselected or counted by the ledger',
    () async {
      final f = _fixture();
      final first = (await f.commit('reselect-fixed', [
        _portion(fixedOwner: LocalDatabaseScope.keyForOwner(f.db.localOwnerId)),
      ])).after.single;
      final other = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'other-owner',
      );
      addTearDown(other.close);
      final food = await (f.db.select(
        f.db.foods,
      )..where((row) => row.id.equals(first.item.foodId))).getSingle();
      await other.into(other.foods).insert(food.toCompanion(true));
      final repository = MealRepository(other);
      await expectLater(
        repository.addReviewedMealItemsAtomically(
          date: nextDay,
          mealType: 'lunch',
          items: [(foodId: food.id, quantity: 75.0)],
        ),
        _conflict(CoachMealConflictReason.invalidEvidence),
      );
      expect(await other.select(other.meals).get(), isEmpty);
      final originalMeal = await f.db.select(f.db.meals).getSingle();
      await other.into(other.meals).insert(originalMeal.toCompanion(true));
      await other.into(other.mealItems).insert(first.item.toCompanion(true));
      final ledger = await DailyLogRepository(other).readLedger(_foodDate);
      expect(ledger.calories, isNull);
      expect(ledger.protein, isNull);
      final row = (await repository.watchMealsForDate(_foodDate).first).single;
      expect(row.ownerKey, LocalDatabaseScope.keyForOwner(other.localOwnerId));
      expect(
        MealFoodEvidence.read(row.items.single, ownerKey: row.ownerKey).isValid,
        false,
      );
      expect((await f.meals.getMealItem(first.item.id)), first.item);
    },
  );
}
