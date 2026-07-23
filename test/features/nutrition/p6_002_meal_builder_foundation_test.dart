import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_builder.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_builder_engine.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test(
    'meal builder canonicalizes order and creates one atomic meal',
    () async {
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final oats = await foods.addFood(
        name: 'Oats',
        category: 'grain',
        calories: 389,
        protein: 16.9,
        carbs: 66.3,
        fats: 6.9,
      );
      final yogurt = await foods.addFood(
        name: 'Greek yogurt',
        category: 'dairy',
        calories: 100,
        protein: 10,
        carbs: 8,
        fats: 3,
      );

      final mealId = await meals.createMealFromDraft(
        date: DateTime(2026, 7, 23),
        draft: MealBuilderDraft(
          name: '  Breakfast bowl  ',
          mealType: 'breakfast',
          items: <MealBuilderItemDraft>[
            MealBuilderItemDraft(
              foodId: yogurt,
              quantityGrams: 150,
              position: 20,
            ),
            MealBuilderItemDraft(foodId: oats, quantityGrams: 50, position: 10),
          ],
        ),
      );

      final storedMeal = await (database.select(
        database.meals,
      )..where((row) => row.id.equals(mealId))).getSingle();
      final storedItems =
          await (database.select(database.mealItems)
                ..where((row) => row.mealId.equals(mealId))
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get();

      expect(storedMeal.name, 'Breakfast bowl');
      expect(storedItems.map((item) => item.foodId), <int>[oats, yogurt]);
      expect(storedItems.map((item) => item.position), <int>[1, 2]);
      expect(storedItems.first.calories, closeTo(194.5, 0.001));
      expect(storedItems.last.calories, closeTo(150, 0.001));
    },
  );

  test('meal builder rejects invalid drafts before persistence', () async {
    final meals = MealRepository(database);

    await expectLater(
      meals.createMealFromDraft(
        date: DateTime(2026, 7, 23),
        draft: const MealBuilderDraft(
          name: ' ',
          mealType: 'breakfast',
          items: <MealBuilderItemDraft>[],
        ),
      ),
      throwsArgumentError,
    );

    expect(await database.select(database.meals).get(), isEmpty);
    expect(await database.select(database.mealItems).get(), isEmpty);
  });

  test(
    'meal builder rolls back when any referenced food is unavailable',
    () async {
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final oats = await foods.addFood(
        name: 'Oats',
        category: 'grain',
        calories: 389,
        protein: 16.9,
        carbs: 66.3,
        fats: 6.9,
      );

      await expectLater(
        meals.createMealFromDraft(
          date: DateTime(2026, 7, 23),
          draft: MealBuilderDraft(
            name: 'Breakfast',
            mealType: 'breakfast',
            items: <MealBuilderItemDraft>[
              MealBuilderItemDraft(
                foodId: oats,
                quantityGrams: 50,
                position: 1,
              ),
              const MealBuilderItemDraft(
                foodId: 999999,
                quantityGrams: 100,
                position: 2,
              ),
            ],
          ),
        ),
        throwsStateError,
      );

      expect(await database.select(database.meals).get(), isEmpty);
      expect(await database.select(database.mealItems).get(), isEmpty);
    },
  );

  test('engine rejects duplicate positions and invalid quantities', () {
    const engine = MealBuilderEngine();
    final validation = engine.validate(
      const MealBuilderDraft(
        name: 'Lunch',
        mealType: 'lunch',
        items: <MealBuilderItemDraft>[
          MealBuilderItemDraft(foodId: 1, quantityGrams: 100, position: 1),
          MealBuilderItemDraft(
            foodId: 2,
            quantityGrams: double.nan,
            position: 1,
          ),
        ],
      ),
    );

    expect(validation.isValid, isFalse);
    expect(
      validation.issues.map((issue) => issue.kind),
      containsAll(<MealBuilderIssueKind>[
        MealBuilderIssueKind.invalidQuantity,
        MealBuilderIssueKind.duplicatePosition,
      ]),
    );
  });
}
