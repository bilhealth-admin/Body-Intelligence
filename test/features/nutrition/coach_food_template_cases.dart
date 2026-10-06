part of 'coach_food_commit_test.dart';

Future<MealTemplate> _savedFoodTemplate(_FoodFixture fixture) async {
  final source =
      (await fixture.meals.watchMealsForDate(_foodDate).first).single;
  return fixture.meals.createTemplateFromHistoricalMeal(
    meal: source,
    templateId: 'food-template',
    templateName: 'Saved food evidence',
  );
}

void _foodTemplateCases() {
  test(
    'template preserves all 13 nutrients and provenance after catalog edits',
    () async {
      final f = _fixture();
      final original = (await f.commit('template-original', [
        _portion(),
      ])).after.single.item;
      final template = await _savedFoodTemplate(f);
      expect(template.items.single.foodEvidenceJson, original.foodEvidenceJson);
      await (f.db.update(
        f.db.foods,
      )..where((row) => row.id.equals(original.foodId))).write(
        const FoodsCompanion(
          calories: Value(999),
          iron: Value(88),
          vitaminC: Value(77),
          name: Value('Changed current catalog'),
        ),
      );
      final day = DateTime(2026, 10, 7);
      final mealId = await f.meals.instantiateTemplate(
        template: template,
        date: day,
      );
      final saved = (await f.meals.watchMealsForDate(day).first).single;
      expect(saved.meal.id, mealId);
      expect(saved.items.single.foodEvidenceJson, original.foodEvidenceJson);
      final evidence = MealFoodEvidence.read(saved.items.single);
      expect(evidence.state, MealFoodEvidenceState.valid);
      expect(evidence.portion!.food.name, 'Synthetic label food');
      expect(evidence.fullValue(FoodNutrient.calories), 240);
      expect(evidence.fullValue(FoodNutrient.iron), 3);
      expect(evidence.fullValue(FoodNutrient.vitaminC), isNull);
      expect(evidence.portion!.food.source.confidence!.score, .9);
      expect(evidence.portion!.identityConfidence!.score, .7);
      expect(evidence.portion!.quantity.evidence.confidence!.score, .8);
      expect((await f.active()).first, original);
    },
  );

  test(
    'template keeps modern all-unknown mask0 unavailable in daily readback',
    () async {
      final f = _fixture();
      await f.commit('template-unknown', [_portion(nutrients: {})]);
      final template = await _savedFoodTemplate(f);
      final day = DateTime(2026, 10, 7);
      await f.meals.instantiateTemplate(template: template, date: day);
      final row =
          (await f.meals.watchMealsForDate(day).first).single.items.single;
      expect(row.nutrientEvidenceMask, 0);
      expect(MealFoodEvidence.read(row).state, MealFoodEvidenceState.valid);
      expect(MealFoodEvidence.read(row).values.values, everyElement(isNull));
      final ledger = await DailyLogRepository(f.db).readLedger(day);
      expect(ledger.calories, isNull);
      expect(ledger.protein, isNull);
      expect(ledger.carbohydrates, isNull);
      expect(ledger.fat, isNull);
    },
  );

  test(
    'corrupted historical evidence cannot become a reusable template',
    () async {
      final f = _fixture();
      final original = (await f.commit('template-invalid', [
        _portion(),
      ])).after.single.item;
      await (f.db.update(f.db.mealItems)
            ..where((row) => row.id.equals(original.id)))
          .write(const MealItemsCompanion(foodEvidenceJson: Value('{invalid')));
      await expectLater(
        _savedFoodTemplate(f),
        _conflict(CoachMealConflictReason.invalidEvidence),
      );
      expect(await f.active(), hasLength(1));
    },
  );

  test(
    'another owner cannot instantiate fixed values and leaves no partial meal',
    () async {
      final f = _fixture();
      final original = (await f.commit('template-fixed', [
        _portion(fixedOwner: LocalDatabaseScope.keyForOwner(f.db.localOwnerId)),
      ])).after.single.item;
      final template = await _savedFoodTemplate(f);
      final other = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'another-owner',
      );
      addTearDown(other.close);
      final food = await (f.db.select(
        f.db.foods,
      )..where((row) => row.id.equals(original.foodId))).getSingle();
      await other.into(other.foods).insert(food.toCompanion(true));
      await expectLater(
        MealRepository(
          other,
        ).instantiateTemplate(template: template, date: DateTime(2026, 10, 7)),
        _conflict(CoachMealConflictReason.invalidEvidence),
      );
      expect(await other.select(other.meals).get(), isEmpty);
      expect(await other.select(other.mealItems).get(), isEmpty);
      expect(await f.active(), [original]);
    },
  );

  test(
    'template detects a corrupted inserted projection and rolls back the batch',
    () async {
      final f = _fixture();
      final original = await f.commit('template-readback', [
        _portion(name: 'First'),
        _portion(name: 'Second'),
      ]);
      final template = await _savedFoodTemplate(f);
      await f.db.customStatement('''
      CREATE TRIGGER corrupt_template AFTER INSERT ON meal_items
      WHEN NEW.position = 2
      BEGIN UPDATE meal_items SET calories = 999 WHERE id = NEW.id; END
    ''');
      final day = DateTime(2026, 10, 7);
      await expectLater(
        f.meals.instantiateTemplate(template: template, date: day),
        _conflict(CoachMealConflictReason.invalidEvidence),
      );
      expect(await f.meals.watchMealsForDate(day).first, isEmpty);
      expect(await f.active(), original.after.map((saved) => saved.item));
    },
  );
}
