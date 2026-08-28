import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late FoodRepository repository;
  late FoodRuntimeSearchAuthority authority;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = FoodRepository(database);
    authority = FoodRuntimeSearchAuthority(
      repository,
      catalogResolver: () async => null,
    );
  });

  tearDown(() => database.close());

  test('text search preserves the existing local repository result', () async {
    await repository.addFood(
      name: 'Chicken Breast',
      arabicName: 'صدر دجاج',
      category: 'protein',
      calories: 165,
      protein: 31,
      carbs: 0,
      fats: 3.6,
      source: 'foundation',
      isCustom: false,
      verified: true,
    );

    final direct = await repository.search('صدر');
    final throughAuthority = await authority.search('صدر');

    expect(
      throughAuthority.map((food) => food.id),
      direct.map((food) => food.id),
    );
    expect(throughAuthority.single.name, 'Chicken Breast');
  });

  test('barcode lookup preserves the existing local match', () async {
    await repository.addFood(
      name: 'Verified product',
      category: 'branded',
      barcode: '4006381333931',
      calories: 100,
      protein: 5,
      carbs: 12,
      fats: 3,
      source: 'branded',
      isCustom: false,
      verified: true,
    );

    final direct = await repository.search('4006381333931');
    final throughAuthority = await authority.lookupBarcode('4006381333931');

    expect(
      throughAuthority.map((food) => food.id),
      direct.map((food) => food.id),
    );
    expect(throughAuthority.single.barcode, '4006381333931');
  });

  test('empty search keeps personalized local ordering behavior', () async {
    final firstId = await repository.addFood(
      name: 'Alpha',
      category: 'food',
      calories: 10,
      protein: 1,
      carbs: 1,
      fats: 1,
      servingSize: 100,
      servingUnit: 'g',
    );
    await repository.addFood(
      name: 'Beta',
      category: 'food',
      calories: 20,
      protein: 2,
      carbs: 2,
      fats: 2,
      servingSize: 100,
      servingUnit: 'g',
    );
    await repository.setFavorite(firstId, true);

    final direct = await repository.search('');
    final throughAuthority = await authority.search('');

    expect(
      throughAuthority.map((food) => food.id),
      direct.map((food) => food.id),
    );
    expect(throughAuthority.first.id, firstId);
  });

  test('strict local scan recovers when the search index misses', () async {
    await repository.addFood(
      name: 'Chicken Breast',
      arabicName: 'صدر دجاج',
      category: 'protein',
      calories: 165,
      protein: 31,
      carbs: 0,
      fats: 3.6,
      source: 'foundation',
      isCustom: false,
      verified: true,
    );
    final resilientAuthority = FoodRuntimeSearchAuthority(
      _ForcedSearchMissRepository(database),
      catalogResolver: () async => null,
    );

    final results = await resilientAuthority.search('chicken');

    expect(results.map((food) => food.name), ['Chicken Breast']);
  });
}

class _ForcedSearchMissRepository extends FoodRepository {
  _ForcedSearchMissRepository(super.database);

  @override
  Future<List<Food>> search(String query, {int limit = 50}) async =>
      const <Food>[];
}
