import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Food API and unified repository API coexist offline', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = FoodRepository(database);

    await repository.addFood(
      name: 'Chicken Breast',
      arabicName: 'صدر دجاج',
      category: 'Protein',
      calories: 165,
      protein: 31,
      carbs: 0,
      fats: 3.6,
      fiber: 0,
      isCustom: false,
      source: 'foundation',
      verified: true,
    );
    await repository.addFood(
      name: 'Brand Yogurt',
      arabicName: 'زبادي تجاري',
      category: 'Dairy',
      calories: 90,
      protein: 7,
      carbs: 10,
      fats: 2,
      barcode: '6221234567890',
      isCustom: false,
      source: 'branded',
    );

    final legacyRows = await repository.search('صدر');
    expect(legacyRows.single.name, 'Chicken Breast');

    final unifiedHits = await repository.searchUnified('٦٢٢١٢٣٤٥٦٧٨٩٠');
    expect(unifiedHits.single.food.source, FoodDataSource.branded);

    final byBarcode = await repository.findByBarcode('622-1234567890');
    expect(byBarcode?.name, 'Brand Yogurt');

    final all = await repository.getAll();
    expect(all, hasLength(2));
  });
}
