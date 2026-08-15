import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/mobile_catalog_food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/offline_barcode_resolver.dart';

void main() {
  late Database database;
  late MobileCatalogFoodRepository repository;

  setUp(() {
    database = sqlite3.openInMemory();
    database.execute('''
      CREATE TABLE catalog_metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE food(bil_food_id TEXT PRIMARY KEY, food_kind TEXT NOT NULL, name_en TEXT, name_ar TEXT, normalized_name TEXT, quality_score REAL NOT NULL, market_code TEXT, updated_at TEXT NOT NULL);
      CREATE TABLE alias(alias_id INTEGER PRIMARY KEY AUTOINCREMENT, bil_food_id TEXT NOT NULL, language TEXT NOT NULL, name TEXT NOT NULL, normalized_name TEXT NOT NULL, name_type TEXT NOT NULL);
      CREATE TABLE nutrient(bil_food_id TEXT NOT NULL, bil_nutrient_id TEXT NOT NULL, amount REAL NOT NULL, unit TEXT NOT NULL, basis TEXT NOT NULL, confidence REAL NOT NULL);
      CREATE TABLE portion(portion_id INTEGER PRIMARY KEY, bil_food_id TEXT NOT NULL, amount REAL NOT NULL, unit_code TEXT NOT NULL, gram_weight REAL, description_en TEXT, description_ar TEXT, confidence REAL NOT NULL);
      CREATE TABLE barcode(normalized_gtin TEXT NOT NULL, bil_food_id TEXT NOT NULL, market_code TEXT, confidence REAL NOT NULL);
      CREATE VIRTUAL TABLE food_fts USING fts5(bil_food_id UNINDEXED, name_en, name_ar, aliases, tokenize='unicode61 remove_diacritics 2');
      INSERT INTO catalog_metadata VALUES('profile', '{"profile_id":"core-eg"}');
      INSERT INTO food VALUES('bil-food-1','generic','Milk','حليب','milk',98,'EG','2026-07-27T00:00:00Z');
      INSERT INTO alias(bil_food_id,language,name,normalized_name,name_type) VALUES('bil-food-1','en','Skimmed milk','skimmed milk','alias');
      INSERT INTO nutrient VALUES('bil-food-1','protein',10,'g','100g',0.95);
      INSERT INTO nutrient VALUES('bil-food-1','usda:1008',42,'KCAL','per_100g',0.98);
      INSERT INTO nutrient VALUES('bil-food-1','usda:1003',3.4,'G','per_100g',0.98);
      INSERT INTO nutrient VALUES('bil-food-1','usda:1004',1,'G','per_100g',0.98);
      INSERT INTO nutrient VALUES('bil-food-1','usda:1005',5,'G','per_100g',0.98);
      INSERT INTO nutrient VALUES('bil-food-1','usda:1079',0.2,'G','per_100g',0.98);
      INSERT INTO nutrient VALUES('bil-food-1','usda:1093',44,'MG','per_100g',0.98);
      INSERT INTO nutrient VALUES('bil-food-1','usda:1092',150,'MG','per_100g',0.98);
      INSERT INTO portion VALUES(1,'bil-food-1',1,'cup',240,'cup',NULL,0.9);
      INSERT INTO barcode VALUES('6221234567891','bil-food-1','EG',0.95);
      INSERT INTO food_fts(bil_food_id,name_en,name_ar,aliases) VALUES('bil-food-1','Milk','حليب','Skimmed milk');
    ''');
    repository = MobileCatalogFoodRepository.fromDatabase(database);
  });

  tearDown(() {
    repository.close();
    database.close();
  });

  test('opens only the BIL delivery schema and exposes metadata', () {
    expect(repository.profileId, 'core-eg');
  });

  test(
    'maps catalog rows to UnifiedFood without external source ids',
    () async {
      final food = await repository.findById('bil-food-1');
      expect(food, isNotNull);
      expect(food!.id, 'bil-food-1');
      expect(food.sourceLabel, 'bil-mobile-catalog');
      expect(food.serving.grams, 240);
      expect(food.knownValue(FoodNutrient.protein), 3.4);
      expect(food.knownValue(FoodNutrient.calories), 42);
      expect(food.knownValue(FoodNutrient.fat), 1);
      expect(food.knownValue(FoodNutrient.carbohydrates), 5);
      expect(food.knownValue(FoodNutrient.fiber), 0.2);
      expect(food.knownValue(FoodNutrient.sodium), 44);
      expect(food.knownValue(FoodNutrient.potassium), 150);
    },
  );

  test('offline search uses existing explainable search pipeline', () async {
    final hits = await repository.searchUnified('skimmed milk');
    expect(hits, hasLength(1));
    expect(hits.single.food.id, 'bil-food-1');
    expect(hits.single.reasons, isNotEmpty);
  });

  test(
    'barcode resolver returns canonical food and preserves ambiguity rules',
    () async {
      final result = await repository.resolveBarcode('6221234567891');
      expect(result.status, BarcodeResolutionStatus.resolved);
      expect(result.food?.id, 'bil-food-1');
    },
  );

  test('repository is read-only and closes deterministically', () {
    repository.close();
    expect(repository.getAll, throwsStateError);
  });

  test('invalid catalog schema is rejected', () {
    final invalid = sqlite3.openInMemory();
    addTearDown(invalid.close);
    expect(
      () => MobileCatalogFoodRepository.fromDatabase(invalid),
      throwsStateError,
    );
  });
}
