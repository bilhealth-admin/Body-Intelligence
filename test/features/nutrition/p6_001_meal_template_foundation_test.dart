import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/meal_template.dart';
import 'package:body_intelligence_log/features/nutrition/services/meal_template_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('historical meal becomes an immutable ordered template', () async {
    final foods = FoodRepository(database);
    final meals = MealRepository(database);
    final oatsId = await foods.addFood(
      name: 'Oats',
      category: 'grain',
      calories: 389,
      protein: 16.9,
      carbs: 66.3,
      fats: 6.9,
      fiber: 10.6,
    );
    final yogurtId = await foods.addFood(
      name: 'Greek yogurt',
      category: 'dairy',
      calories: 100,
      protein: 10,
      carbs: 8,
      fats: 3,
    );
    final sourceDate = DateTime(2026, 7, 20);
    final mealId = await meals.createMeal(
      date: sourceDate,
      name: 'Breakfast',
      type: 'breakfast',
    );
    await meals.addMealItem(mealId: mealId, foodId: oatsId, quantity: 50);
    await meals.addMealItem(mealId: mealId, foodId: yogurtId, quantity: 150);

    final source = (await meals.watchMealsForDate(sourceDate).first).single;
    final template = meals.createTemplateFromHistoricalMeal(
      meal: source,
      templateId: 'template:breakfast:1',
      templateName: 'My breakfast',
      createdAt: DateTime(2026, 7, 21),
    );

    expect(template.name, 'My breakfast');
    expect(template.mealType, 'breakfast');
    expect(template.sourceMealUuid, source.meal.uuid);
    expect(template.items, hasLength(2));
    expect(template.items.map((item) => item.position), [1, 2]);
    expect(template.items.first.foodId, oatsId);
    expect(template.items.first.quantityGrams, 50);
    expect(template.totalCalories, closeTo(344.5, 0.001));
  });

  test('template instantiation preserves nutrition snapshots', () async {
    final foods = FoodRepository(database);
    final meals = MealRepository(database);
    final foodId = await foods.addFood(
      name: 'Snapshot food',
      category: 'custom',
      calories: 200,
      protein: 20,
      carbs: 10,
      fats: 8,
      sodium: 100,
    );
    final sourceDate = DateTime(2026, 7, 20);
    final sourceMealId = await meals.createMeal(
      date: sourceDate,
      name: 'Lunch',
      type: 'lunch',
    );
    await meals.addMealItem(mealId: sourceMealId, foodId: foodId, quantity: 75);
    final source = (await meals.watchMealsForDate(sourceDate).first).single;
    final template = meals.createTemplateFromHistoricalMeal(
      meal: source,
      templateId: 'template:lunch:1',
      templateName: 'Saved lunch',
    );

    await foods.updateCustomFood(
      id: foodId,
      name: 'Snapshot food updated',
      category: 'custom',
      servingSize: 100,
      servingUnit: 'g',
      calories: 400,
      protein: 40,
      carbs: 20,
      fats: 16,
      sodium: 200,
    );

    final targetDate = DateTime(2026, 7, 22);
    final targetMealId = await meals.instantiateTemplate(
      template: template,
      date: targetDate,
    );
    final target = (await meals.watchMealsForDate(targetDate).first).single;

    expect(target.meal.id, targetMealId);
    expect(target.meal.name, 'Saved lunch');
    expect(target.items, hasLength(1));
    expect(target.items.single.quantity, 75);
    expect(target.items.single.calories, 150);
    expect(target.items.single.protein, 15);
    expect(target.items.single.sodium, 75);
  });

  test(
    'invalid and conflicting templates fail without partial writes',
    () async {
      final foods = FoodRepository(database);
      final meals = MealRepository(database);
      final foodId = await foods.addFood(
        name: 'Conflict food',
        category: 'custom',
        calories: 100,
        protein: 1,
        carbs: 1,
        fats: 1,
      );
      final date = DateTime(2026, 7, 23);
      final mealId = await meals.createMeal(
        date: date,
        name: 'Dinner',
        type: 'dinner',
      );
      await meals.addMealItem(mealId: mealId, foodId: foodId, quantity: 100);

      final template = MealTemplate(
        id: 'template:dinner:1',
        name: 'Dinner template',
        mealType: 'dinner',
        createdAt: DateTime(2026, 7, 23),
        items: <MealTemplateItem>[
          MealTemplateItem(
            foodId: 1,
            quantityGrams: 100,
            position: 1,
            calories: 100,
            protein: 1,
            carbohydrates: 1,
            fat: 1,
            fiber: 0,
            sodium: 0,
            potassium: 0,
            calcium: 0,
            magnesium: 0,
            sugar: 0,
            nutrientEvidenceMask: 0,
          ),
        ],
      );

      await expectLater(
        meals.instantiateTemplate(template: template, date: date),
        throwsStateError,
      );
      final stored = (await meals.watchMealsForDate(date).first).single;
      expect(stored.items, hasLength(1));
    },
  );

  test('engine rejects blank identity and empty templates', () {
    const engine = MealTemplateEngine();
    final template = MealTemplate(
      id: '',
      name: '',
      mealType: 'breakfast',
      createdAt: DateTime(2026, 7, 23),
      items: <MealTemplateItem>[],
    );

    expect(() => engine.validateForInstantiation(template), throwsStateError);
  });
}
