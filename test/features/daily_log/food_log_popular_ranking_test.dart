import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late FoodRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = FoodRepository(database);
  });

  tearDown(() => database.close());

  test('popular foods require more than three confirmed selections', () async {
    final foodId = await repository.addFood(
      name: 'Popular food',
      category: 'food',
      calories: 100,
      protein: 10,
      carbs: 10,
      fats: 2,
      servingSize: 100,
      servingUnit: 'g',
    );

    for (var count = 0; count < 3; count++) {
      await repository.recordRecent(foodId);
    }
    expect(await repository.popularFoods(), isEmpty);

    await repository.recordRecent(foodId);
    final popular = await repository.popularFoods();
    expect(popular.map((food) => food.id), [foodId]);
  });

  test('most-used popular food has priority', () async {
    final firstId = await repository.addFood(
      name: 'First',
      category: 'food',
      calories: 100,
      protein: 10,
      carbs: 10,
      fats: 2,
      servingSize: 100,
      servingUnit: 'g',
    );
    final secondId = await repository.addFood(
      name: 'Second',
      category: 'food',
      calories: 100,
      protein: 10,
      carbs: 10,
      fats: 2,
      servingSize: 100,
      servingUnit: 'g',
    );
    for (var count = 0; count < 4; count++) {
      await repository.recordRecent(firstId);
      await repository.recordRecent(secondId);
    }
    await repository.recordRecent(firstId);

    final popular = await repository.popularFoods();
    expect(popular.map((food) => food.id), [firstId, secondId]);
  });
}
