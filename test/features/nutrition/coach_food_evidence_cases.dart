part of 'coach_food_commit_test.dart';

void _foodEvidenceCases() {
  test(
    'modern all-unknown mask0 stays unknown through real ledger and Dashboard',
    () async {
      final f = _fixture();
      final result = await f.commit('unknown', [_portion(nutrients: {})]);
      final item = result.after.single.item;
      expect(item.nutrientEvidenceMask, 0);
      expect(item.foodEvidenceJson, isNotNull);
      expect(MealFoodEvidence.read(item).state, MealFoodEvidenceState.valid);
      expect(MealFoodEvidence.read(item).values.values, everyElement(isNull));
      for (final nutrient in [
        'calories',
        'protein',
        'carbohydrates',
        'fat',
        'iron_mg',
        'vitamin_c_mg',
      ]) {
        expect(result.after.single.toReceiptPayload()[nutrient], isNull);
      }
      final ledger = await DailyLogRepository(f.db).readLedger(_foodDate);
      expect(ledger.calories, isNull);
      expect(ledger.protein, isNull);
      expect(ledger.carbohydrates, isNull);
      expect(ledger.fat, isNull);
      final dashboard = await f.dashboard();
      expect(dashboard.calories, isNull);
      expect(dashboard.protein, isNull);
    },
  );

  test(
    'known zero remains different from unknown in full readback and daily totals',
    () async {
      final f = _fixture();
      final result = await f.commit('zero', [
        _portion(
          nutrients: {
            FoodNutrient.calories: 0,
            FoodNutrient.protein: 0,
            FoodNutrient.carbohydrates: 0,
            FoodNutrient.fat: 0,
            FoodNutrient.iron: 0,
            FoodNutrient.vitaminC: null,
          },
        ),
      ]);
      final evidence = MealFoodEvidence.read(result.after.single.item);
      expect(evidence.value(TrackedNutrient.calories), 0);
      expect(evidence.fullValue(FoodNutrient.iron), 0);
      expect(evidence.fullValue(FoodNutrient.vitaminC), isNull);
      final ledger = await DailyLogRepository(f.db).readLedger(_foodDate);
      expect(ledger.calories, 0);
      expect(ledger.protein, 0);
    },
  );

  final corruptions = <String, MealItemsCompanion>{
    'lost modern envelope': const MealItemsCompanion(
      foodEvidenceJson: Value(null),
    ),
    'invalid JSON': const MealItemsCompanion(
      foodEvidenceJson: Value('{invalid'),
    ),
    'unknown schema': const MealItemsCompanion(
      foodEvidenceJson: Value('{"schema":"future"}'),
    ),
    'changed numeric projection': const MealItemsCompanion(
      calories: Value(900),
    ),
    'changed quantity projection': const MealItemsCompanion(
      quantity: Value(100),
    ),
    'changed evidence mask': const MealItemsCompanion(
      nutrientEvidenceMask: Value(0),
    ),
    'unearned verification': const MealItemsCompanion(
      foodVerifiedSnapshot: Value(true),
    ),
  };
  for (final entry in corruptions.entries) {
    test(
      '${entry.key} cannot fall back to legacy zero or become a receipt',
      () async {
        final f = _fixture();
        final first = (await f.commit('original', [
          _portion(),
        ])).after.single.item;
        await (f.db.update(
          f.db.mealItems,
        )..where((row) => row.id.equals(first.id))).write(entry.value);
        final changed = await f.meals.getMealItem(first.id);
        final evidence = MealFoodEvidence.read(changed);
        expect(evidence.state, MealFoodEvidenceState.invalid);
        expect(evidence.values.values, everyElement(isNull));
        final ledger = await DailyLogRepository(f.db).readLedger(_foodDate);
        expect(ledger.calories, isNull);
        final dashboard = await f.dashboard();
        expect(dashboard.calories, isNull);
        expect(dashboard.protein, isNull);
        await expectLater(
          f.meals.readCoachMealOperation(
            operationId: 'original',
            scope: f.scope(),
          ),
          _conflict(CoachMealConflictReason.invalidEvidence),
        );
        await expectLater(
          f.meals.updateMealItem(id: first.id, quantity: 60),
          _conflict(CoachMealConflictReason.invalidEvidence),
        );
        expect((await f.active()).single, changed);
      },
    );
  }

  test(
    'lost modern mask0 envelope stays invalid and never becomes known zero',
    () async {
      final f = _fixture();
      final saved = (await f.commit('lost-unknown', [
        _portion(nutrients: {}),
      ])).after.single.item;
      await (f.db.update(f.db.mealItems)
            ..where((row) => row.id.equals(saved.id)))
          .write(const MealItemsCompanion(foodEvidenceJson: Value(null)));
      final item = await f.meals.getMealItem(saved.id);
      expect(item.nutrientEvidenceMask, 0);
      final evidence = MealFoodEvidence.read(item);
      expect(evidence.isModern, true);
      expect(evidence.state, MealFoodEvidenceState.invalid);
      expect(evidence.values.values, everyElement(isNull));
      expect(
        (await DailyLogRepository(f.db).readLedger(_foodDate)).calories,
        isNull,
      );
      expect((await f.dashboard()).calories, isNull);
      await expectLater(
        f.meals.readCoachMealOperation(
          operationId: 'lost-unknown',
          scope: f.scope(),
        ),
        _conflict(CoachMealConflictReason.invalidEvidence),
      );
    },
  );

  test(
    'copy day, historical repeat and duplication preserve the full saved snapshot',
    () async {
      final f = _fixture();
      final original = (await f.commit('original', [
        _portion(),
      ])).after.single.item;
      final id = await f.meals.duplicateMealItem(original.id);
      expect(
        (await f.meals.getMealItem(id)).foodEvidenceJson,
        original.foodEvidenceJson,
      );
      await f.meals.copyDay(
        sourceDate: _foodDate,
        destinationDate: DateTime(2026, 10, 7),
      );
      final historical =
          (await f.meals.watchMealsForDate(_foodDate).first).single;
      await f.meals.repeatHistoricalMeal(
        meal: historical,
        date: DateTime(2026, 10, 8),
      );
      final saved = await f.active();
      expect(saved, hasLength(6));
      for (final row in saved) {
        expect(row.foodEvidenceJson, original.foodEvidenceJson);
        expect(MealFoodEvidence.read(row).isValid, true);
        expect(MealFoodEvidence.read(row).fullValue(FoodNutrient.iron), 3);
        expect(
          MealFoodEvidence.read(row).fullValue(FoodNutrient.vitaminC),
          isNull,
        );
      }
    },
  );

  test(
    'closed day blocks a new batch without changing existing snapshots',
    () async {
      final f = _fixture();
      final first = await f.commit('before-close', [_portion()]);
      await f.db
          .into(f.db.dailyLogs)
          .insert(
            DailyLogsCompanion.insert(
              date: _foodDate,
              dayKey: '2026-10-06',
              lifecycleState: const Value('closed'),
              closedAt: Value(_foodDate),
            ),
          );
      await expectLater(
        f.commit('closed', [_portion(name: 'Not written')]),
        _conflict(CoachMealConflictReason.closedDay),
      );
      expect(await f.active(), [first.after.single.item]);
      expect(await f.db.select(f.db.preferences).get(), hasLength(1));
    },
  );
}
