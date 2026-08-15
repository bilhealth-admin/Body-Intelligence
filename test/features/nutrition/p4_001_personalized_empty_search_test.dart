import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty search preserves favorites then frequency ranking', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final foods = FoodRepository(database);

    final frequent = await foods.addFood(
      name: 'Frequent oats',
      category: 'grain',
      barcode: '123456789',
      calories: 380,
      protein: 15,
      carbs: 65,
      fats: 7,
      servingSize: 100,
      servingUnit: 'g',
    );
    final favorite = await foods.addFood(
      name: 'Favorite yogurt',
      category: 'dairy',
      calories: 95,
      protein: 8,
      carbs: 10,
      fats: 3,
      servingSize: 100,
      servingUnit: 'g',
    );
    await foods.addFood(
      name: 'Alphabetical apple',
      category: 'fruit',
      calories: 52,
      protein: 0.3,
      carbs: 14,
      fats: 0.2,
      servingSize: 100,
      servingUnit: 'g',
    );

    await foods.recordRecent(frequent);
    await foods.recordRecent(frequent);
    await foods.setFavorite(favorite, true);

    final ranked = await foods.search('');
    expect(ranked.map((food) => food.id).take(2), [favorite, frequent]);
    expect((await foods.search('123456789')).single.id, frequent);
  });
}
