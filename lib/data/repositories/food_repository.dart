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
    this._adapter = const UnifiedFoodAdapter(),
    this._searchPipeline = const OfflineFoodSearchPipeline(),
    this._barcodeResolver = const OfflineBarcodeResolver(),
    this._foodAccessEngine = const FoodAccessEngine(),
  });

  Future<int> addFood({
    required String name,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    String? arabicName,
    String? barcode,
    double? servingSize,
    String? servingUnit,
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
    double? phosphorus,
    double iron = 0,
    double vitaminC = 0,
    String? uuid,
    bool caloriesKnown = true,
    bool proteinKnown = true,
    bool carbsKnown = true,
    bool fatsKnown = true,
  }) async {
    final normalizedBarcode = _optional(barcode);
    if (isCustom && normalizedBarcode != null) {
      _validateCustomBarcode(normalizedBarcode);
    }
    if (isCustom && (servingSize == null || servingUnit == null)) {
      throw ArgumentError(
        'Custom foods require an explicit serving size and serving unit',
      );
    }
    final effectiveServingSize = servingSize ?? 100;
    final normalizedServingUnit = _validateServingUnit(servingUnit ?? 'g');
    _validateNutritionBounds(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      potassium: potassium,
      calcium: calcium,
      magnesium: magnesium,
      phosphorus: phosphorus,
    );
    _validateFood(
      name: name,
      servingSize: effectiveServingSize,
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
        phosphorus ?? 0,
        iron,
        vitaminC,
      ],
    );
    // Open/migrate the lazy database before entering the serialized barcode
    // check+insert transaction. Initializing the schema from inside the first
    // transaction can deadlock NativeDatabase during cold-start tests.
    await (_database.select(_database.foods)..limit(1)).get();
    return _database.transaction(() async {
      if (isCustom && normalizedBarcode != null) {
        await _ensureBarcodeAvailable(normalizedBarcode);
      }
      return _database
          .into(_database.foods)
          .insert(
            FoodsCompanion.insert(
              uuid: uuid == null ? const Value.absent() : Value(uuid),
              name: name.trim(),
              arabicName: Value(_optional(arabicName)),
              category: Value(category),
              keywords: Value(keywords.trim()),
              barcode: Value(normalizedBarcode),
              servingSize: Value(effectiveServingSize),
              servingUnit: Value(normalizedServingUnit),
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
              phosphorus: Value(phosphorus ?? 0),
              nutrientEvidenceMask: Value(
                NutrientEvidenceMask.fromValues(
                  fiber: fiber,
                  sugar: sugar,
                  sodium: sodium,
                  potassium: potassium,
                  calcium: calcium,
                  magnesium: magnesium,
                  phosphorus: phosphorus,
                  calories: caloriesKnown ? calories : null,
                  protein: proteinKnown ? protein : null,
                  carbohydrates: carbsKnown ? carbs : null,
                  fat: fatsKnown ? fats : null,
                ),
              ),
              vitaminC: Value(vitaminC),
              verified: Value(verified),
              isCustom: Value(isCustom),
              source: Value(source.trim().isEmpty ? 'local' : source.trim()),
            ),
          );
    });
  }

  Stream<List<Food>> watchFavorites() async* {
    final query =
        _database.select(_database.foods).join([
            innerJoin(
              _database.favorites,
              _database.favorites.foodId.equalsExp(_database.foods.id),
            ),
          ])
          ..where(_database.foods.deletedAt.isNull())
          ..orderBy([OrderingTerm.asc(_database.foods.name)]);
    List<Food> decode(List<TypedResult> rows) =>
        rows.map((row) => row.readTable(_database.foods)).toList();
    yield decode(await query.get());
    yield* query.watch().map(decode).skip(1);
  }

  Stream<List<Food>> watchRecent({int limit = 20}) async* {
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
    List<Food> decode(List<TypedResult> rows) =>
        rows.map((row) => row.readTable(_database.foods)).toList();
    yield decode(await query.get());
    yield* query.watch().map(decode).skip(1);
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

  Future<void> repairBundledFoodNutrients({
    required int id,
    required String source,
    required double fiber,
    required double sugar,
    required double sodium,
    required double potassium,
    required double calcium,
    required double magnesium,
    double? phosphorus,
  }) async {
    final food = await (_database.select(
      _database.foods,
    )..where((row) => row.id.equals(id))).getSingle();
    if (food.isCustom) return;
    await (_database.update(
      _database.foods,
    )..where((row) => row.id.equals(id))).write(
      FoodsCompanion(
        fiber: Value(fiber),
        sugar: Value(sugar),
        sodium: Value(sodium),
        potassium: Value(potassium),
        calcium: Value(calcium),
        magnesium: Value(magnesium),
        phosphorus: Value(phosphorus ?? 0),
        nutrientEvidenceMask: Value(
          food.nutrientEvidenceMask |
              NutrientEvidenceMask.fromValues(
                fiber: fiber,
                sugar: sugar,
                sodium: sodium,
                potassium: potassium,
                calcium: calcium,
                magnesium: magnesium,
                phosphorus: phosphorus,
              ),
        ),
        source: Value(source),
        verified: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
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
    double? phosphorus,
    bool caloriesKnown = true,
    bool proteinKnown = true,
    bool carbsKnown = true,
    bool fatsKnown = true,
  }) async {
    final normalizedBarcode = _optional(barcode);
    if (normalizedBarcode != null) {
      _validateCustomBarcode(normalizedBarcode);
    }
    final normalizedServingUnit = _validateServingUnit(servingUnit);
    _validateNutritionBounds(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      potassium: potassium,
      calcium: calcium,
      magnesium: magnesium,
      phosphorus: phosphorus,
    );
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
        phosphorus ?? 0,
      ],
    );
    await _database.transaction(() async {
      if (normalizedBarcode != null) {
        await _ensureBarcodeAvailable(normalizedBarcode, excludingId: id);
      }
      final existing = await _customFood(id);
      await (_database.update(
        _database.foods,
      )..where((row) => row.id.equals(id))).write(
        FoodsCompanion(
          name: Value(name.trim()),
          arabicName: Value(_optional(arabicName)),
          category: Value(category),
          barcode: Value(normalizedBarcode),
          servingSize: Value(servingSize),
          servingUnit: Value(normalizedServingUnit),
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
          phosphorus: Value(phosphorus ?? 0),
          nutrientEvidenceMask: Value(
            NutrientEvidenceMask.fromValues(
              fiber: fiber,
              sugar: sugar,
              sodium: sodium,
              potassium: potassium,
              calcium: calcium,
              magnesium: magnesium,
              phosphorus: phosphorus,
              calories: caloriesKnown ? calories : null,
              protein: proteinKnown ? protein : null,
              carbohydrates: carbsKnown ? carbs : null,
              fat: fatsKnown ? fats : null,
            ),
          ),
          updatedAt: Value(DateTime.now()),
          revision: Value(existing.revision + 1),
          syncStatus: const Value('pending'),
        ),
      );
    });
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

  Future<Food> materializeUnifiedFood(UnifiedFood food) async {
    final byUuid = await (_database.select(
      _database.foods,
    )..where((row) => row.uuid.equals(food.id))).getSingleOrNull();
    if (byUuid != null) {
      final incomingCalories = food.knownValue(FoodNutrient.calories);
      final incomingProtein = food.knownValue(FoodNutrient.protein);
      final incomingCarbs = food.knownValue(FoodNutrient.carbohydrates);
      final incomingFats = food.knownValue(FoodNutrient.fat);

      final incomingHasCoreEvidence =
          incomingCalories != null ||
          incomingProtein != null ||
          incomingCarbs != null ||
          incomingFats != null;
      final storedCoreIsZero =
          byUuid.calories == 0 &&
          byUuid.protein == 0 &&
          byUuid.carbs == 0 &&
          byUuid.fats == 0;

      if (!incomingHasCoreEvidence || !storedCoreIsZero) return byUuid;

      await (_database.update(
        _database.foods,
      )..where((row) => row.id.equals(byUuid.id))).write(
        FoodsCompanion(
          name: Value(food.name),
          arabicName: Value(_optional(food.arabicName)),
          category: Value(food.category ?? byUuid.category),
          keywords: Value(food.keywords.join(',')),
          servingSize: Value(food.serving.amount),
          servingUnit: Value(food.serving.unit),
          calories: Value(incomingCalories ?? byUuid.calories),
          protein: Value(incomingProtein ?? byUuid.protein),
          carbs: Value(incomingCarbs ?? byUuid.carbs),
          fats: Value(incomingFats ?? byUuid.fats),
          fiber: Value(food.knownValue(FoodNutrient.fiber) ?? byUuid.fiber),
          sugar: Value(food.knownValue(FoodNutrient.sugar) ?? byUuid.sugar),
          sodium: Value(food.knownValue(FoodNutrient.sodium) ?? byUuid.sodium),
          potassium: Value(
            food.knownValue(FoodNutrient.potassium) ?? byUuid.potassium,
          ),
          calcium: Value(
            food.knownValue(FoodNutrient.calcium) ?? byUuid.calcium,
          ),
          magnesium: Value(
            food.knownValue(FoodNutrient.magnesium) ?? byUuid.magnesium,
          ),
          phosphorus: Value(
            food.knownValue(FoodNutrient.phosphorus) ?? byUuid.phosphorus,
          ),
          iron: Value(food.knownValue(FoodNutrient.iron) ?? byUuid.iron),
          vitaminC: Value(
            food.knownValue(FoodNutrient.vitaminC) ?? byUuid.vitaminC,
          ),
          nutrientEvidenceMask: Value(
            byUuid.nutrientEvidenceMask |
                NutrientEvidenceMask.fromValues(
                  calories: incomingCalories,
                  protein: incomingProtein,
                  carbohydrates: incomingCarbs,
                  fat: incomingFats,
                  fiber: food.knownValue(FoodNutrient.fiber),
                  sugar: food.knownValue(FoodNutrient.sugar),
                  sodium: food.knownValue(FoodNutrient.sodium),
                  potassium: food.knownValue(FoodNutrient.potassium),
                  calcium: food.knownValue(FoodNutrient.calcium),
                  magnesium: food.knownValue(FoodNutrient.magnesium),
                  phosphorus: food.knownValue(FoodNutrient.phosphorus),
                ),
          ),
          source: Value(food.sourceLabel),
          verified: Value(food.verified),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return (_database.select(
        _database.foods,
      )..where((row) => row.id.equals(byUuid.id))).getSingle();
    }

    final barcode = food.barcode?.trim();
    if (barcode != null && barcode.isNotEmpty) {
      final byBarcode = await (_database.select(
        _database.foods,
      )..where((row) => row.barcode.equals(barcode))).getSingleOrNull();
      if (byBarcode != null) return byBarcode;
    }

    final id = await addFood(
      uuid: food.id,
      name: food.name,
      arabicName: food.arabicName,
      category: food.category ?? 'food',
      keywords: food.keywords.join(','),
      barcode: barcode,
      servingSize: food.serving.amount,
      servingUnit: food.serving.unit,
      calories: food.knownValue(FoodNutrient.calories) ?? 0,
      protein: food.knownValue(FoodNutrient.protein) ?? 0,
      carbs: food.knownValue(FoodNutrient.carbohydrates) ?? 0,
      fats: food.knownValue(FoodNutrient.fat) ?? 0,
      fiber: food.knownValue(FoodNutrient.fiber),
      sugar: food.knownValue(FoodNutrient.sugar),
      sodium: food.knownValue(FoodNutrient.sodium),
      potassium: food.knownValue(FoodNutrient.potassium),
      calcium: food.knownValue(FoodNutrient.calcium),
      magnesium: food.knownValue(FoodNutrient.magnesium),
      phosphorus: food.knownValue(FoodNutrient.phosphorus),
      iron: food.knownValue(FoodNutrient.iron) ?? 0,
      vitaminC: food.knownValue(FoodNutrient.vitaminC) ?? 0,
      source: food.sourceLabel,
      isCustom: false,
      verified: food.verified,
      caloriesKnown: food.knownValue(FoodNutrient.calories) != null,
      proteinKnown: food.knownValue(FoodNutrient.protein) != null,
      carbsKnown: food.knownValue(FoodNutrient.carbohydrates) != null,
      fatsKnown: food.knownValue(FoodNutrient.fat) != null,
    );

    return (_database.select(
      _database.foods,
    )..where((row) => row.id.equals(id))).getSingle();
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

  void _validateCustomBarcode(String barcode) {
    if (!RegExp(r'^\d{8,14}$').hasMatch(barcode)) {
      throw ArgumentError.value(
        barcode,
        'barcode',
        'A custom barcode must contain 8 to 14 digits',
      );
    }
  }

  String _validateServingUnit(String value) {
    final unit = value.trim();
    if (unit.isEmpty ||
        unit.length > 24 ||
        !RegExp(r'^[\p{L}][\p{L}\p{N} ._-]*$', unicode: true).hasMatch(unit)) {
      throw ArgumentError.value(
        value,
        'servingUnit',
        'A short serving unit is required',
      );
    }
    return unit;
  }

  void _validateNutritionBounds({
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    double? fiber,
    double? sugar,
    double? sodium,
    double? potassium,
    double? calcium,
    double? magnesium,
    double? phosphorus,
  }) {
    final macroValues = [protein, carbs, fats, fiber ?? 0, sugar ?? 0];
    final microValues = [
      sodium ?? 0,
      potassium ?? 0,
      calcium ?? 0,
      magnesium ?? 0,
      phosphorus ?? 0,
    ];
    if (calories > 10000 ||
        macroValues.any((value) => value > 2000) ||
        microValues.any((value) => value > 1000000)) {
      throw ArgumentError('Food nutrition values exceed supported bounds');
    }
  }

  Future<void> _ensureBarcodeAvailable(
    String barcode, {
    int? excludingId,
  }) async {
    final query = _database.select(_database.foods)
      ..where(
        (row) =>
            row.barcode.equals(barcode) &
            row.deletedAt.isNull() &
            (excludingId == null
                ? const Constant(true)
                : row.id.equals(excludingId).not()),
      );
    if (await query.getSingleOrNull() != null) {
      throw StateError('A food with this barcode already exists');
    }
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
        servingSize > 100000 ||
        nutrients.any(
          (value) => !value.isFinite || value < 0 || value > 1000000,
        )) {
      throw ArgumentError('Food quantities and nutrients must be valid');
    }
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
