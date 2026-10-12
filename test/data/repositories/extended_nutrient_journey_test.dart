import 'dart:convert';
import 'dart:io';
import 'package:body_intelligence_log/app/services/local_data_lifecycle_service.dart';
import 'package:body_intelligence_log/app/services/local_recovery_service.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/food_basis_evidence.dart';
import 'package:body_intelligence_log/data/database/meal_food_evidence.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FoodRepository foods;
  late MealRepository meals;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory(), localOwnerId: 'A');
    foods = FoodRepository(db);
    meals = MealRepository(db);
  });
  tearDown(() => db.close());
  test(
    'custom food transaction rolls back when the owner changes before commit',
    () async {
      var checks = 0;
      await expectLater(
        foods.addFood(
          name: 'TEST retired',
          category: 'custom',
          calories: 1,
          protein: 0,
          carbs: 0,
          fats: 0,
          servingSize: 100,
          servingUnit: 'g',
          isCurrent: () => ++checks < 3,
        ),
        throwsStateError,
      );
      expect(await db.select(db.foods).get(), isEmpty);
    },
  );
  UnifiedFood fixture({double saturated = 1}) => UnifiedFood(
    id: 'usda:stage1-test-food',
    name: 'TEST food with nineteen nutrients',
    serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
    source: FoodDataSource.foundation,
    sourceLabel: 'TEST USDA source',
    verified: true,
    isCustom: false,
    nutrients: {
      for (final n in FoodNutrient.values)
        n: n == FoodNutrient.transFat
            ? const NutrientAmount.missing()
            : NutrientAmount.known(switch (n) {
                FoodNutrient.calories => 100,
                FoodNutrient.protein => 5,
                FoodNutrient.carbohydrates => 15,
                FoodNutrient.fat => 2,
                FoodNutrient.fiber => 2,
                FoodNutrient.sugar => 1,
                FoodNutrient.saturatedFat => saturated,
                FoodNutrient.monounsaturatedFat => 0.5,
                FoodNutrient.polyunsaturatedFat => 0,
                FoodNutrient.cholesterol => 0,
                FoodNutrient.vitaminA => 120,
                _ => 4,
              }),
    },
  );

  test(
    'nineteen fields and immutable source survive JSON CSV snapshot reset restore and owner isolation',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'bil-nutrient-recovery-',
      );
      addTearDown(() => root.delete(recursive: true));
      final food = await foods.materializeUnifiedFood(fixture());
      await meals.addReviewedMealItemsAtomically(
        date: DateTime(2026, 10, 11),
        mealType: 'lunch',
        quantitiesInGrams: true,
        items: [(foodId: food.id, quantity: 80.0)],
      );
      final item = await db.select(db.mealItems).getSingle();
      final before = MealFoodEvidence.read(item);
      final lifecycle = LocalDataLifecycleService(db);
      final exported =
          jsonDecode(await lifecycle.exportJson(displayUnits: 'metric')) as Map;
      expect(
        exported['mealItems'].single['foodEvidenceJson'],
        item.foodEvidenceJson,
      );
      final csv = (await lifecycle.exportCsvFiles())['BIL-meal-nutrition.csv']!;
      for (final field in [
        'vitaminAMcgRae',
        'transFatG',
        'cholesterolMg',
        'polyunsaturatedFatG',
        'ironMg',
        'vitaminCMg',
      ]) {
        expect(csv, contains('"$field"'));
      }
      final lines = csv.split('\r\n');
      final headers = lines.first
          .split(',')
          .map((value) => value.replaceAll('"', ''))
          .toList();
      final cells = lines.last.split(
        ',',
      ); // Numeric columns precede escaped evidence JSON.
      expect(cells[headers.indexOf('vitaminAMcgRae')], '"96.0"');
      expect(cells[headers.indexOf('transFatG')], '""');
      expect(cells[headers.indexOf('cholesterolMg')], '"0.0"');
      final recovery = LocalRecoveryService(
        db,
        directoryResolver: () async => root,
      );
      await recovery.resetWithRecovery();
      expect(await db.select(db.mealItems).get(), isEmpty);
      await recovery.restore();
      final restored = await db.select(db.mealItems).getSingle();
      expect(restored.foodEvidenceJson, item.foodEvidenceJson);
      final after = MealFoodEvidence.read(restored);
      for (final nutrient in FoodNutrient.values) {
        expect(
          after.fullValue(nutrient),
          before.fullValue(nutrient),
          reason: nutrient.name,
        );
      }
      final other = AppDatabase.forTesting(
        NativeDatabase.memory(),
        localOwnerId: 'B',
      );
      try {
        final otherRecovery = LocalRecoveryService(
          other,
          directoryResolver: () async => root,
        );
        expect(await otherRecovery.hasValidSnapshot(), isFalse);
        await expectLater(
          otherRecovery.restore(),
          throwsA(isA<RecoverySnapshotException>()),
        );
        expect(await other.select(other.mealItems).get(), isEmpty);
      } finally {
        await other.close();
      }
      expect(
        (await db.select(db.mealItems).getSingle()).foodEvidenceJson,
        item.foodEvidenceJson,
      );
    },
  );
  test(
    'all nineteen nutrients survive materialization fractional logging correction and duplicate',
    () async {
      final food = await foods.materializeUnifiedFood(fixture());
      final basis = FoodBasisEvidence.read(food);
      expect(basis.isValid, isTrue);
      expect(basis.value(FoodNutrient.polyunsaturatedFat), 0);
      expect(basis.value(FoodNutrient.transFat), isNull);
      final day = DateTime(2026, 10, 11);
      await meals.addReviewedMealItemsAtomically(
        date: day,
        mealType: 'lunch',
        quantitiesInGrams: true,
        items: [(foodId: food.id, quantity: 80.0)],
      );
      final item = await db.select(db.mealItems).getSingle();
      final evidence = MealFoodEvidence.read(item);
      expect(evidence.isValid, isTrue);
      expect(evidence.fullValue(FoodNutrient.vitaminA), 96);
      expect(evidence.fullValue(FoodNutrient.saturatedFat), 0.8);
      expect(evidence.fullValue(FoodNutrient.cholesterol), 0);
      expect(evidence.fullValue(FoodNutrient.transFat), isNull);
      await foods.materializeUnifiedFood(fixture(saturated: 2));
      expect(
        MealFoodEvidence.read(
          await meals.getMealItem(item.id),
        ).fullValue(FoodNutrient.saturatedFat),
        0.8,
        reason: 'catalog edit cannot rewrite historical food',
      );
      await meals.updateMealItem(id: item.id, quantity: 160);
      final corrected = await meals.getMealItem(item.id);
      expect(
        MealFoodEvidence.read(corrected).fullValue(FoodNutrient.saturatedFat),
        1.6,
      );
      final copy = await meals.duplicateMealItem(item.id);
      expect(
        MealFoodEvidence.read(
          await meals.getMealItem(copy),
        ).fullValue(FoodNutrient.vitaminA),
        192,
      );
      expect(
        jsonDecode(
          corrected.foodEvidenceJson!,
        )['portion']['food']['nutrients'].length,
        19,
      );
    },
  );

  test(
    'fractional recipe serving keeps all extra nutrients and known zero',
    () async {
      await meals.addCalculatedRecipeServingAtomically(
        date: DateTime(2026, 10, 11),
        mealType: 'breakfast',
        foodUuid: 'TEST-recipe19',
        recipeName: 'TEST وصفة',
        source: 'TEST exact selected ingredients',
        calories: 200,
        protein: 10,
        carbohydrates: 20,
        fat: 10,
        servings: 0.25,
        additionalNutrients: {
          FoodNutrient.vitaminA: 120,
          FoodNutrient.cholesterol: 0,
          FoodNutrient.saturatedFat: 2,
          FoodNutrient.monounsaturatedFat: 1,
          FoodNutrient.polyunsaturatedFat: 0.5,
        },
      );
      final item = await db.select(db.mealItems).getSingle();
      final evidence = MealFoodEvidence.read(item);
      expect(evidence.fullValue(FoodNutrient.vitaminA), 30);
      expect(evidence.fullValue(FoodNutrient.cholesterol), 0);
      expect(evidence.fullValue(FoodNutrient.transFat), isNull);
      expect(item.servingUnitSnapshot, 'serving');
      await meals.updateMealItem(id: item.id, quantity: 0.5);
      expect(
        MealFoodEvidence.read(
          await meals.getMealItem(item.id),
        ).fullValue(FoodNutrient.vitaminA),
        60,
      );
    },
  );
  test(
    'custom ml food preserves source, nineteen fields, deletion and historical fractional units without an invented mass',
    () async {
      final id = await foods.addFood(
        name: 'TEST milk',
        arabicName: 'حليب اختبار',
        category: 'custom',
        calories: 100,
        protein: 5,
        carbs: 10,
        fats: 4,
        servingSize: 100,
        servingUnit: 'ml',
        source: 'https://example.test/TEST-label',
        iron: 0,
        vitaminC: 2,
        additionalNutrients: {
          FoodNutrient.vitaminA: 80,
          FoodNutrient.transFat: 0,
        },
      );
      final food = (await db.select(db.foods).get()).single;
      expect(FoodBasisEvidence.read(food).basisGrams, isNull);
      await meals.addReviewedMealItemsAtomically(
        date: DateTime(2026, 10, 11),
        mealType: 'snack',
        items: [(foodId: id, quantity: 25.0)],
        quantitiesInGrams: false,
      );
      final item = await db.select(db.mealItems).getSingle();
      final evidence = MealFoodEvidence.read(item);
      expect(evidence.isValid, isTrue);
      expect(item.servingUnitSnapshot, 'ml');
      expect(evidence.fullValue(FoodNutrient.vitaminA), 20);
      expect(evidence.fullValue(FoodNutrient.iron), 0);
      expect(evidence.fullValue(FoodNutrient.transFat), 0);
      expect(evidence.fullValue(FoodNutrient.cholesterol), isNull);
      await meals.updateMealItem(id: item.id, quantity: 12.5);
      expect(
        MealFoodEvidence.read(
          await meals.getMealItem(item.id),
        ).fullValue(FoodNutrient.vitaminA),
        10,
      );
      final copy = await meals.duplicateMealItem(item.id);
      expect(
        MealFoodEvidence.read(
          await meals.getMealItem(copy),
        ).fullValue(FoodNutrient.vitaminA),
        10,
      );
      await foods.updateCustomFood(
        id: id,
        name: 'TEST changed milk',
        category: 'custom',
        calories: 200,
        protein: 8,
        carbs: 12,
        fats: 6,
        servingSize: 100,
        servingUnit: 'ml',
        source: 'https://example.test/TEST-new',
        additionalNutrients: {FoodNutrient.vitaminA: 160},
      );
      await foods.deleteCustomFood(id);
      expect(await foods.search('TEST changed milk'), isEmpty);
      expect(
        MealFoodEvidence.read(
          await meals.getMealItem(item.id),
        ).fullValue(FoodNutrient.vitaminA),
        10,
      );
      expect(
        MealFoodEvidence.read(await meals.getMealItem(item.id)).unit!.source,
        'https://example.test/TEST-label',
      );
    },
  );
}
