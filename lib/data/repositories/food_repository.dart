import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/nutrient_evidence.dart';
import '../../features/nutrition/adapters/unified_food_adapter.dart';
import '../../features/nutrition/domain/food_access.dart';
import '../../features/nutrition/domain/unified_food.dart';
import '../../features/nutrition/repositories/unified_food_repository.dart';
import '../../features/nutrition/services/food_access_engine.dart';
import '../../features/nutrition/services/food_deduplication_engine.dart';
import '../../features/nutrition/services/food_foundation_integrity_engine.dart';
import '../../features/nutrition/services/food_migration_engine.dart';
import '../../features/nutrition/services/food_quality_engine.dart';
import '../../features/nutrition/services/food_search_normalizer.dart';
import '../../features/nutrition/services/offline_food_search_pipeline.dart';
import '../../features/nutrition/services/offline_barcode_resolver.dart';

class FoodRepository implements UnifiedFoodRepository {
  final AppDatabase _database;
  final UnifiedFoodAdapter _adapter;
  final OfflineFoodSearchPipeline _searchPipeline;
  final OfflineBarcodeResolver _barcodeResolver;
  final FoodAccessEngine _foodAccessEngine;

  FoodRepository(
    this._database, {
    UnifiedFoodAdapter adapter = const UnifiedFoodAdapter(),
    OfflineFoodSearchPipeline searchPipeline =
        const OfflineFoodSearchPipeline(),
    OfflineBarcodeResolver barcodeResolver = const OfflineBarcodeResolver(),
    FoodAccessEngine foodAccessEngine = const FoodAccessEngine(),
  }) : _adapter = adapter,
       _searchPipeline = searchPipeline,
       _barcodeResolver = barcodeResolver,
       _foodAccessEngine = foodAccessEngine;

  Future<int> addFood({
    required String name,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    String? arabicName,
    String? barcode,
    double servingSize = 100,
    String servingUnit = 'g',
    bool isCustom = true,
    String source = 'local',
    bool verified = false,
    String keywords = '',
    double? fiber,
    double? sugar,
    double? sodium,
    double? potassium,
    double? calcium,
    double? magnesium,
    double iron = 0,
    double vitaminC = 0,
  }) async {
    _validateFood(
      name: name,
      servingSize: servingSize,
      nutrients: [
        calories,
        protein,
        carbs,
        fats,
        fiber ?? 0,
        sugar ?? 0,
        sodium ?? 0,
        potassium ?? 0,
        calcium ?? 0,
        magnesium ?? 0,
        iron,
        vitaminC,
      ],
    );
    final rowId = await _database
        .into(_database.foods)
        .insert(
          FoodsCompanion.insert(
            name: name.trim(),
            arabicName: Value(_optional(arabicName)),
            category: Value(category),
            keywords: Value(keywords.trim()),
            barcode: Value(_optional(barcode)),
            servingSize: Value(servingSize),
            servingUnit: Value(servingUnit),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: Value(fiber ?? 0),
            sugar: Value(sugar ?? 0),
            potassium: Value(potassium ?? 0),
            sodium: Value(sodium ?? 0),
            calcium: Value(calcium ?? 0),
            iron: Value(iron),
            magnesium: Value(magnesium ?? 0),
            nutrientEvidenceMask: Value(
              NutrientEvidenceMask.fromValues(
                fiber: fiber,
                sugar: sugar,
                sodium: sodium,
                potassium: potassium,
                calcium: calcium,
                magnesium: magnesium,
              ),
            ),
            vitaminC: Value(vitaminC),
            verified: Value(verified),
            isCustom: Value(isCustom),
            source: Value(source.trim().isEmpty ? 'local' : source.trim()),
          ),
        );

    return rowId;
  }

  Stream<List<Food>> watchFavorites() {
    final query =
        _database.select(_database.foods).join([
            innerJoin(
              _database.favorites,
              _database.favorites.foodId.equalsExp(_database.foods.id),
            ),
          ])
          ..where(_database.foods.deletedAt.isNull())
          ..orderBy([OrderingTerm.asc(_database.foods.name)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_database.foods)).toList(),
    );
  }

  Stream<List<Food>> watchRecent({int limit = 20}) {
    final query =
        _database.select(_database.foods).join([
            innerJoin(
              _database.recentFoods,
              _database.recentFoods.foodId.equalsExp(_database.foods.id),
            ),
          ])
          ..where(_database.foods.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(_database.recentFoods.lastUsedAt)])
          ..limit(limit);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_database.foods)).toList(),
    );
  }

  Stream<List<Food>> watchFoods() {
    return (_database.select(_database.foods)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<Food>> getFoods() {
    return (_database.select(_database.foods)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<void> updateCustomFood({
    required int id,
    required String name,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    String? arabicName,
    String? barcode,
    required double servingSize,
    required String servingUnit,
    double? fiber,
    double? sugar,
    double? sodium,
    double? potassium,
    double? calcium,
    double? magnesium,
  }) async {
    _validateFood(
      name: name,
      servingSize: servingSize,
      nutrients: [
        calories,
        protein,
        carbs,
        fats,
        fiber ?? 0,
        sugar ?? 0,
        sodium ?? 0,
        potassium ?? 0,
        calcium ?? 0,
        magnesium ?? 0,
      ],
    );
    final existing = await _customFood(id);
    await (_database.update(
      _database.foods,
    )..where((row) => row.id.equals(id))).write(
      FoodsCompanion(
        name: Value(name.trim()),
        arabicName: Value(_optional(arabicName)),
        category: Value(category),
        barcode: Value(_optional(barcode)),
        servingSize: Value(servingSize),
        servingUnit: Value(
          servingUnit.trim().isEmpty ? 'g' : servingUnit.trim(),
        ),
        calories: Value(calories),
        protein: Value(protein),
        carbs: Value(carbs),
        fats: Value(fats),
        fiber: Value(fiber ?? 0),
        sugar: Value(sugar ?? 0),
        sodium: Value(sodium ?? 0),
        potassium: Value(potassium ?? 0),
        calcium: Value(calcium ?? 0),
        magnesium: Value(magnesium ?? 0),
        nutrientEvidenceMask: Value(
          NutrientEvidenceMask.fromValues(
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            potassium: potassium,
            calcium: calcium,
            magnesium: magnesium,
          ),
        ),
        updatedAt: Value(DateTime.now()),
        revision: Value(existing.revision + 1),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> deleteCustomFood(int id) async {
    final existing = await _customFood(id);
    final now = DateTime.now();
    await (_database.update(
      _database.foods,
    )..where((row) => row.id.equals(id))).write(
      FoodsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        revision: Value(existing.revision + 1),
        syncStatus: const Value('pendingDelete'),
      ),
    );
  }

  Future<List<Food>> search(String query, {int limit = 50}) async {
    final foods = await getFoods();
    if (FoodSearchNormalizer.normalize(query).isEmpty) {
      return _rankPersonalizedFoods(foods, limit: limit);
    }

    final hits = _searchPipeline.search(
      foods: _adapter.adaptAll(foods),
      query: query,
      limit: limit,
    );
    final byId = <int, Food>{for (final food in foods) food.id: food};
    return hits
        .map((hit) => hit.food.localId == null ? null : byId[hit.food.localId!])
        .whereType<Food>()
        .toList(growable: false);
  }

  @override
  Future<List<FoodSearchHit>> searchUnified(
    String query, {
    int limit = 50,
  }) async {
    final foods = await getFoods();
    if (FoodSearchNormalizer.normalize(query).isEmpty) {
      final ranked = await _rankPersonalizedFoods(foods, limit: limit);
      return List<FoodSearchHit>.unmodifiable(
        ranked.map(
          (food) => FoodSearchHit(
            food: _adapter.adapt(food),
            score: 1,
            reasons: const <String>['personalized-empty-query'],
          ),
        ),
      );
    }

    return _searchPipeline.search(
      foods: _adapter.adaptAll(foods),
      query: query,
      limit: limit,
    );
  }

  @override
  Stream<List<UnifiedFood>> watchAll() => watchFoods().map(_adapter.adaptAll);

  @override
  Future<List<UnifiedFood>> getAll() async =>
      _adapter.adaptAll(await getFoods());

  @override
  Future<UnifiedFood?> findById(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) return null;
    final food =
        await (_database.select(_database.foods)..where(
              (row) => row.uuid.equals(normalized) & row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return food == null ? null : _adapter.adapt(food);
  }

  @override
  Future<UnifiedFood?> findByBarcode(String barcode) async {
    final normalized = FoodSearchNormalizer.normalizeBarcode(barcode);
    if (normalized.isEmpty) return null;
    final foods = await getFoods();
    for (final food in foods) {
      if (FoodSearchNormalizer.normalizeBarcode(food.barcode ?? '') ==
          normalized) {
        return _adapter.adapt(food);
      }
    }
    return null;
  }

  @override
  Future<BarcodeResolution> resolveBarcode(String barcode) async {
    return _barcodeResolver.resolve(
      barcode: barcode,
      foods: _adapter.adaptAll(await getFoods()),
    );
  }

  @override
  Future<List<FoodDuplicateCandidate>> findDuplicateCandidates(
    UnifiedFood incoming, {
    FoodDuplicateKind minimumKind = FoodDuplicateKind.possible,
    int limit = 20,
  }) async {
    final existing = _adapter.adaptAll(await getFoods());
    return FoodDeduplicationEngine.findCandidates(
      incoming: incoming,
      existing: existing,
      minimumKind: minimumKind,
      limit: limit,
    );
  }

  @override
  Future<List<FoodMigrationPlan>> auditMigration({int limit = 1000}) async {
    return FoodMigrationEngine.auditAll(
      _adapter.adaptAll(await getFoods()),
      limit: limit,
    );
  }

  @override
  Future<FoodQualityAudit> auditQuality({
    FoodConfidenceLevel? maximumConfidence,
    FoodQualityIssue? issue,
    int limit = 1000,
  }) async {
    return FoodQualityAuditEngine.audit(
      _adapter.adaptAll(await getFoods()),
      maximumConfidence: maximumConfidence,
      issue: issue,
      limit: limit,
    );
  }

  @override
  Future<FoodFoundationIntegrityReport> auditFoundationIntegrity({
    int migrationLimit = 1000,
    int duplicatePairLimit = 10000,
  }) async {
    return FoodFoundationIntegrityEngine.audit(
      _adapter.adaptAll(await getFoods()),
      migrationLimit: migrationLimit,
      duplicatePairLimit: duplicatePairLimit,
    );
  }

  Future<List<Food>> _rankPersonalizedFoods(
    List<Food> foods, {
    required int limit,
  }) async {
    if (limit <= 0 || foods.isEmpty) return const <Food>[];

    final favoriteRows = await _database.select(_database.favorites).get();
    final recentRows = await _database.select(_database.recentFoods).get();
    final favoriteIds = favoriteRows.map((row) => row.foodId).toSet();
    final recentsByFoodId = {for (final row in recentRows) row.foodId: row};

    final ranked = List<Food>.of(foods);
    ranked.sort((left, right) {
      final favoriteOrder = (favoriteIds.contains(right.id) ? 1 : 0).compareTo(
        favoriteIds.contains(left.id) ? 1 : 0,
      );
      if (favoriteOrder != 0) return favoriteOrder;

      final leftRecent = recentsByFoodId[left.id];
      final rightRecent = recentsByFoodId[right.id];
      final useCountOrder = (rightRecent?.useCount ?? 0).compareTo(
        leftRecent?.useCount ?? 0,
      );
      if (useCountOrder != 0) return useCountOrder;

      final lastUsedOrder =
          (rightRecent?.lastUsedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                leftRecent?.lastUsedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0),
              );
      if (lastUsedOrder != 0) return lastUsedOrder;

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return List<Food>.unmodifiable(ranked.take(limit));
  }

  Future<List<FoodAccessCandidate>> foodAccessCandidates({
    String query = '',
    int limit = 20,
  }) async {
    if (limit <= 0) return const <FoodAccessCandidate>[];
    final foods = await getFoods();
    final favoriteRows = await _database.select(_database.favorites).get();
    final recentRows = await _database.select(_database.recentFoods).get();
    final favoriteIds = favoriteRows.map((row) => row.foodId).toSet();
    final recentsByFoodId = {for (final row in recentRows) row.foodId: row};
    return _foodAccessEngine.rank(
      foods.map((food) {
        final recent = recentsByFoodId[food.id];
        return FoodAccessRecord(
          food: _adapter.adapt(food),
          favorite: favoriteIds.contains(food.id),
          useCount: recent?.useCount ?? 0,
          lastUsedAt: recent?.lastUsedAt,
        );
      }),
      query: query,
      limit: limit,
    );
  }

  Future<void> setFavorite(int foodId, bool favorite) async {
    if (favorite) {
      await _database
          .into(_database.favorites)
          .insert(
            FavoritesCompanion.insert(foodId: foodId),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_database.delete(
        _database.favorites,
      )..where((row) => row.foodId.equals(foodId))).go();
    }
  }

  Future<bool> isFavorite(int foodId) async {
    final row = await (_database.select(
      _database.favorites,
    )..where((favorite) => favorite.foodId.equals(foodId))).getSingleOrNull();
    return row != null;
  }

  Future<void> recordRecent(int foodId) async {
    final existing = await (_database.select(
      _database.recentFoods,
    )..where((row) => row.foodId.equals(foodId))).getSingleOrNull();
    await _database
        .into(_database.recentFoods)
        .insertOnConflictUpdate(
          RecentFoodsCompanion.insert(
            foodId: Value(foodId),
            lastUsedAt: Value(DateTime.now()),
            useCount: Value((existing?.useCount ?? 0) + 1),
          ),
        );
  }

  Future<void> deleteAll() async {
    await _database.delete(_database.foods).go();
  }

  Future<Food> _customFood(int id) async {
    final food =
        await (_database.select(_database.foods)..where(
              (row) =>
                  row.id.equals(id) &
                  row.isCustom.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (food == null) throw StateError('Custom food $id does not exist');
    return food;
  }

  void _validateFood({
    required String name,
    required double servingSize,
    required List<double> nutrients,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'A food name is required');
    }
    if (!servingSize.isFinite ||
        servingSize <= 0 ||
        nutrients.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Food quantities and nutrients must be valid');
    }
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
