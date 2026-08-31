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
part 'food_repository_ranking.dart';
part 'food_repository_validation.dart';
part 'food_repository_access.dart';
part 'food_repository_read_streams.dart';

class FoodRepository
    with _FoodRepositoryReadStreams, _FoodRepositoryAccessMethods
    implements UnifiedFoodRepository {
  @override
  final AppDatabase _database;
  @override
  final UnifiedFoodAdapter _adapter;
  final OfflineFoodSearchPipeline _searchPipeline;
  final OfflineBarcodeResolver _barcodeResolver;
  @override
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

  Stream<List<Food>> watchFoods() {
    return (_database.select(_database.foods)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  @override
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
    final canonicalServingGrams = food.serving.grams;
    if (!canonicalServingGrams.isFinite || canonicalServingGrams <= 0) {
      throw StateError('Catalog food ${food.id} has no valid gram basis');
    }
    final byUuid = await (_database.select(
      _database.foods,
    )..where((row) => row.uuid.equals(food.id))).getSingleOrNull();
    if (byUuid != null) {
      final incomingCalories = food.knownValue(FoodNutrient.calories);
      final incomingProtein = food.knownValue(FoodNutrient.protein);
      final incomingCarbs = food.knownValue(FoodNutrient.carbohydrates);
      final incomingFats = food.knownValue(FoodNutrient.fat);
      final incomingEvidenceMask = NutrientEvidenceMask.fromValues(
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
      );
      final incomingArabicName = _optional(food.arabicName);
      final hasNewEvidence =
          incomingEvidenceMask & ~byUuid.nutrientEvidenceMask != 0;
      final nutrientValuesChanged =
          (incomingCalories != null && byUuid.calories != incomingCalories) ||
          (incomingProtein != null && byUuid.protein != incomingProtein) ||
          (incomingCarbs != null && byUuid.carbs != incomingCarbs) ||
          (incomingFats != null && byUuid.fats != incomingFats) ||
          _knownValueChanged(
            food.knownValue(FoodNutrient.fiber),
            byUuid.fiber,
          ) ||
          _knownValueChanged(
            food.knownValue(FoodNutrient.sugar),
            byUuid.sugar,
          ) ||
          _knownValueChanged(
            food.knownValue(FoodNutrient.sodium),
            byUuid.sodium,
          ) ||
          _knownValueChanged(
            food.knownValue(FoodNutrient.potassium),
            byUuid.potassium,
          ) ||
          _knownValueChanged(
            food.knownValue(FoodNutrient.calcium),
            byUuid.calcium,
          ) ||
          _knownValueChanged(
            food.knownValue(FoodNutrient.magnesium),
            byUuid.magnesium,
          ) ||
          _knownValueChanged(
            food.knownValue(FoodNutrient.phosphorus),
            byUuid.phosphorus,
          );
      final catalogIdentityChanged =
          byUuid.name != food.name ||
          byUuid.arabicName != incomingArabicName ||
          byUuid.source != food.sourceLabel ||
          byUuid.verified != food.verified;
      final servingBasisChanged =
          (byUuid.servingSize - canonicalServingGrams).abs() > 0.0001 ||
          byUuid.servingUnit.toLowerCase() != 'g';

      if (!hasNewEvidence &&
          !nutrientValuesChanged &&
          !catalogIdentityChanged &&
          !servingBasisChanged) {
        return byUuid;
      }

      await (_database.update(
        _database.foods,
      )..where((row) => row.id.equals(byUuid.id))).write(
        FoodsCompanion(
          name: Value(food.name),
          // Null intentionally clears an old lossy generated translation.
          arabicName: Value(incomingArabicName),
          category: Value(food.category ?? byUuid.category),
          keywords: Value(food.keywords.join(',')),
          // The local diary stores quantities as mass. Preserve the catalog's
          // authoritative gram basis so portion labels such as "1 large" do
          // not accidentally become one gram after materialization.
          servingSize: Value(canonicalServingGrams),
          servingUnit: const Value('g'),
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
            byUuid.nutrientEvidenceMask | incomingEvidenceMask,
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
      servingSize: canonicalServingGrams,
      servingUnit: 'g',
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

  Future<List<Food>> searchCustomFoods(String query, {int limit = 50}) async {
    final foods = (await getFoods())
        .where((food) => food.isCustom)
        .toList(growable: false);
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

  bool _knownValueChanged(double? incoming, double stored) =>
      incoming != null && incoming != stored;
}
