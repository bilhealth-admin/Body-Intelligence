part of 'local_intelligence_unknown_nutrition_test.dart';

const _modernKnown = <FoodNutrient, double?>{
  FoodNutrient.calories: 1900,
  FoodNutrient.protein: 145,
  FoodNutrient.carbohydrates: 180,
  FoodNutrient.fat: 65,
  FoodNutrient.sodium: 2100,
  FoodNutrient.potassium: 3200,
};

CoachFoodPortion _modernPortion({
  Map<FoodNutrient, double?> values = _modernKnown,
  String owner = 'runtime-owner',
}) => CoachFoodPortion(
  food: CoachFoodSnapshot(
    identity: 'personal-daily-intake',
    name: 'Personal fixed daily intake',
    preparedState: 'prepared',
    basisGrams: 1000,
    nutrients: CoachFoodNutrients(values),
    source: CoachFoodSourceEvidence(
      kind: CoachFoodSourceKind.userFixed,
      ref: 'personal-fixed:daily-intake',
      revision: '7',
      ownerKey: LocalDatabaseScope.keyForOwner(owner),
    ),
  ),
  quantity: CoachFoodQuantities.declaredGrams(
    1000,
    description: 'Reviewed daily portion',
  ),
);

Future<MealItem> _storeModernPortion(
  _RuntimeNutritionFixture fixture,
  CoachFoodPortion portion,
) async {
  final database = fixture.database;
  final item =
      await (database.select(database.mealItems)
            ..orderBy([(row) => OrderingTerm.asc(row.id)])
            ..limit(1))
          .getSingle();
  final values = MealFoodEvidence.projection(portion);
  await (database.update(
    database.mealItems,
  )..where((row) => row.id.equals(item.id))).write(
    MealItemsCompanion(
      quantity: Value(portion.quantity.grams),
      calories: Value(values[TrackedNutrient.calories] ?? 0),
      protein: Value(values[TrackedNutrient.protein] ?? 0),
      carbs: Value(values[TrackedNutrient.carbohydrates] ?? 0),
      fats: Value(values[TrackedNutrient.fat] ?? 0),
      sodium: Value(values[TrackedNutrient.sodium] ?? 0),
      potassium: Value(values[TrackedNutrient.potassium] ?? 0),
      nutrientEvidenceMask: Value(MealFoodEvidence.mask(portion)),
      foodSourceSnapshot: Value(MealFoodEvidence.sourceLabel(portion)),
      servingSizeSnapshot: Value(portion.food.basisGrams),
      servingUnitSnapshot: const Value('g'),
      foodEvidenceJson: Value(portion.encodeForStorage()),
    ),
  );
  return (database.select(
    database.mealItems,
  )..where((row) => row.id.equals(item.id))).getSingle();
}

void _expectUnknownNutrition(LocalDailyPhysiology day) {
  expect(day.hasNutritionItems, isTrue);
  expect(day.caloriesKcal, isNull);
  expect(day.proteinG, isNull);
  expect(day.carbsG, isNull);
  expect(day.fatG, isNull);
  expect(day.sodiumMg, isNull);
  expect(day.potassiumMg, isNull);
}

void _registerBridgeCases(_RuntimeNutritionFixture Function() fixtureFor) {
  test(
    'empty calendar days do not become recorded zero-nutrient intake',
    () async {
      final fixture = fixtureFor();
      await fixture.seed(_DailyEvidence.complete);
      final timeline = await fixture.timeline();
      final empty = timeline.days.firstWhere((day) => day.day.isBefore(_start));
      expect(empty.hasNutritionItems, isFalse);
      expect(empty.caloriesKcal, isNull);
      expect(empty.proteinG, isNull);
      expect(
        LocalNutritionEvidence.average(
          timeline.days,
          (day) => day.caloriesKcal,
        ),
        1900,
      );
    },
  );

  test(
    'canonical adapter accepts fixed food for the captured account scope',
    () async {
      final fixture = fixtureFor();
      await fixture.seed(_DailyEvidence.complete);
      final item = await _storeModernPortion(fixture, _modernPortion());
      expect(item.foodEvidenceJson, isNotNull);
      final day = fixture.firstRecorded(await fixture.timeline());
      expect(day.caloriesKcal, 1900);
      expect(day.proteinG, 145);
      expect(day.carbsG, 180);
      expect(day.fatG, 65);
      expect(day.sodiumMg, 2100);
      expect(day.potassiumMg, 3200);
    },
  );

  test(
    'another account fixed food cannot support canonical intelligence',
    () async {
      final fixture = fixtureFor();
      await fixture.seed(_DailyEvidence.complete);
      await _storeModernPortion(
        fixture,
        _modernPortion(owner: 'previous-owner'),
      );
      _expectUnknownNutrition(fixture.firstRecorded(await fixture.timeline()));
      final output = await fixture.runtime();
      expect(output.forecast, isEmpty);
      expect(output.plateauRisk, isNull);
      expect(output.brainResult.selectedAction, isNull);
    },
  );

  test(
    'valid modern all-null mask zero never falls back to legacy zero',
    () async {
      final fixture = fixtureFor();
      await fixture.seed(_DailyEvidence.complete);
      final item = await _storeModernPortion(
        fixture,
        _modernPortion(values: const {}),
      );
      expect(item.nutrientEvidenceMask, 0);
      expect(item.calories, 0);
      expect(item.protein, 0);
      expect(MealFoodEvidence.read(item).isValid, isTrue);
      _expectUnknownNutrition(fixture.firstRecorded(await fixture.timeline()));
    },
  );

  test('explicit modern nutrient zero remains known and recorded', () async {
    final fixture = fixtureFor();
    await fixture.seed(_DailyEvidence.complete);
    await _storeModernPortion(
      fixture,
      _modernPortion(
        values: {for (final nutrient in _modernKnown.keys) nutrient: 0},
      ),
    );
    final timeline = await fixture.timeline();
    final day = fixture.firstRecorded(timeline);
    expect(day.hasNutritionItems, isTrue);
    expect(day.caloriesKcal, 0);
    expect(day.proteinG, 0);
    expect(day.carbsG, 0);
    expect(day.fatG, 0);
    expect(day.sodiumMg, 0);
    expect(day.potassiumMg, 0);
    expect(
      LocalNutritionEvidence.average(timeline.days, (day) => day.caloriesKcal),
      closeTo(1900 * 35 / 36, 1e-9),
    );
  });

  final corruptions = <String, MealItemsCompanion Function(MealItem)>{
    'malformed JSON': (_) =>
        const MealItemsCompanion(foodEvidenceJson: Value('{invalid')),
    'raw nutrient projection': (item) =>
        MealItemsCompanion(calories: Value(item.calories + 1)),
    'known mask': (item) => MealItemsCompanion(
      nutrientEvidenceMask: Value(
        item.nutrientEvidenceMask ^
            NutrientEvidenceMask.bit(TrackedNutrient.protein),
      ),
    ),
    'source label': (_) =>
        const MealItemsCompanion(foodSourceSnapshot: Value('label')),
    'basis': (item) => MealItemsCompanion(
      servingSizeSnapshot: Value(item.servingSizeSnapshot + 1),
    ),
    'quantity': (item) =>
        MealItemsCompanion(quantity: Value(item.quantity + 1)),
  };
  for (final corruption in corruptions.entries) {
    test('canonical adapter withholds ${corruption.key} conflicts', () async {
      final fixture = fixtureFor();
      await fixture.seed(_DailyEvidence.complete);
      final item = await _storeModernPortion(fixture, _modernPortion());
      await (fixture.database.update(
        fixture.database.mealItems,
      )..where((row) => row.id.equals(item.id))).write(corruption.value(item));
      final before = await fixture.database
          .select(fixture.database.mealItems)
          .get();
      _expectUnknownNutrition(fixture.firstRecorded(await fixture.timeline()));
      expect(
        await fixture.database.select(fixture.database.mealItems).get(),
        before,
      );
    });
  }
}
