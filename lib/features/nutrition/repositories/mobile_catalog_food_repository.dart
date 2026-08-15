import 'dart:async';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../domain/barcode_identity.dart';
import '../domain/unified_food.dart';
import '../repositories/unified_food_repository.dart';
import '../services/food_deduplication_engine.dart';
import '../services/food_foundation_integrity_engine.dart';
import '../services/food_migration_engine.dart';
import '../services/food_quality_engine.dart';
import '../services/food_search_normalizer.dart';
import '../services/offline_barcode_resolver.dart';
import '../services/offline_food_search_pipeline.dart';

/// Read-only adapter over a BIL mobile catalog produced by BIL-FOOD-006.
///
/// The repository understands only the compact BIL delivery schema. It never
/// reads USDA tables or source-specific identifiers.
class MobileCatalogFoodRepository implements UnifiedFoodRepository {
  final Database _database;
  final bool _ownsDatabase;
  List<UnifiedFood>? _cache;
  bool _closed = false;

  MobileCatalogFoodRepository.open(
    String path, {
    OfflineFoodSearchPipeline searchPipeline =
        const OfflineFoodSearchPipeline(),
    OfflineBarcodeResolver barcodeResolver = const OfflineBarcodeResolver(),
  }) : _database = sqlite3.open(path, mode: OpenMode.readOnly),
       _ownsDatabase = true {
    _validateSchema();
  }

  MobileCatalogFoodRepository.fromDatabase(
    this._database, {
    this._ownsDatabase = false,
    OfflineFoodSearchPipeline searchPipeline =
        const OfflineFoodSearchPipeline(),
    OfflineBarcodeResolver barcodeResolver = const OfflineBarcodeResolver(),
  }) {
    _validateSchema();
  }

  Map<String, String> get metadata {
    _ensureOpen();
    final rows = _database.select('SELECT key, value FROM catalog_metadata');
    return Map<String, String>.unmodifiable({
      for (final row in rows) row['key'] as String: row['value'] as String,
    });
  }

  String? get profileId {
    final raw = metadata['profile'];
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic>
        ? decoded['profile_id'] as String?
        : null;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _cache = null;
    if (_ownsDatabase) _database.close();
  }

  @override
  Stream<List<UnifiedFood>> watchAll() =>
      Stream<List<UnifiedFood>>.fromFuture(getAll());

  @override
  Future<List<UnifiedFood>> getAll() async {
    _ensureOpen();
    return _cache ??= List<UnifiedFood>.unmodifiable(_readFoods());
  }

  @override
  Future<UnifiedFood?> findById(String id) async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT bil_food_id FROM food WHERE bil_food_id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _readFood(id);
  }

  @override
  Future<List<FoodSearchHit>> searchUnified(
    String query, {
    int limit = 50,
  }) async {
    _ensureOpen();
    if (limit <= 0) return const <FoodSearchHit>[];
    final normalized = FoodSearchNormalizer.normalize(query);
    if (normalized.isEmpty) {
      final ids = _database.select(
        'SELECT bil_food_id FROM food ORDER BY quality_score DESC, bil_food_id LIMIT ?',
        <Object?>[limit],
      );
      return List<FoodSearchHit>.unmodifiable(
        ids.map(
          (row) => FoodSearchHit(
            food: _readFood(row['bil_food_id'] as String),
            score: 1,
            reasons: const ['catalog-order'],
          ),
        ),
      );
    }
    final ftsQuery = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) {
          final escaped = token.replaceAll('"', '""');
          return '"$escaped"*';
        })
        .join(' AND ');
    final ids = _database.select(
      'SELECT f.bil_food_id, bm25(food_fts) AS rank '
      'FROM food_fts JOIN food f ON f.bil_food_id = food_fts.bil_food_id '
      'WHERE food_fts MATCH ? ORDER BY rank ASC, f.quality_score DESC LIMIT ?',
      <Object?>[ftsQuery, limit],
    );
    return List<FoodSearchHit>.unmodifiable(
      ids.map(
        (row) => FoodSearchHit(
          food: _readFood(row['bil_food_id'] as String),
          score: 1000 - ((row['rank'] as num?)?.toDouble() ?? 0),
          reasons: const ['sqlite-fts'],
        ),
      ),
    );
  }

  @override
  Future<UnifiedFood?> findByBarcode(String barcode) async {
    final resolution = await resolveBarcode(barcode);
    return resolution.food;
  }

  @override
  Future<BarcodeResolution> resolveBarcode(String barcode) async {
    _ensureOpen();
    final identity = BarcodeIdentity.parse(barcode);
    if (!identity.isValid) {
      return BarcodeResolution(
        identity: identity,
        status: BarcodeResolutionStatus.invalid,
        candidates: const <UnifiedFood>[],
      );
    }
    final rows = _database.select(
      'SELECT bil_food_id FROM barcode WHERE normalized_gtin = ? '
      'ORDER BY confidence DESC, bil_food_id ASC',
      <Object?>[identity.digits],
    );
    final candidates = rows
        .map((row) => _readFood(row['bil_food_id'] as String))
        .toList(growable: false);
    final status = switch (candidates.length) {
      0 => BarcodeResolutionStatus.notFound,
      1 => BarcodeResolutionStatus.resolved,
      _ => BarcodeResolutionStatus.ambiguous,
    };
    return BarcodeResolution(
      identity: identity,
      status: status,
      candidates: List<UnifiedFood>.unmodifiable(candidates),
    );
  }

  @override
  Future<List<FoodDuplicateCandidate>> findDuplicateCandidates(
    UnifiedFood incoming, {
    FoodDuplicateKind minimumKind = FoodDuplicateKind.possible,
    int limit = 20,
  }) async {
    final foods = await getAll();
    final candidates = FoodDeduplicationEngine.findCandidates(
      incoming: incoming,
      existing: foods,
      minimumKind: minimumKind,
      limit: limit,
    );
    return List<FoodDuplicateCandidate>.unmodifiable(candidates);
  }

  @override
  Future<List<FoodMigrationPlan>> auditMigration({int limit = 1000}) async =>
      const <FoodMigrationPlan>[];

  @override
  Future<FoodQualityAudit> auditQuality({
    FoodConfidenceLevel? maximumConfidence,
    FoodQualityIssue? issue,
    int limit = 1000,
  }) async {
    final foods = (await getAll()).take(limit);
    return FoodQualityAuditEngine.audit(
      foods,
      maximumConfidence: maximumConfidence,
      issue: issue,
      limit: limit,
    );
  }

  @override
  Future<FoodFoundationIntegrityReport> auditFoundationIntegrity({
    int migrationLimit = 1000,
    int duplicatePairLimit = 10000,
  }) async => FoodFoundationIntegrityEngine.audit(
    await getAll(),
    migrationLimit: migrationLimit,
    duplicatePairLimit: duplicatePairLimit,
  );

  List<UnifiedFood> _readFoods() {
    final rows = _database.select(
      'SELECT bil_food_id FROM food ORDER BY quality_score DESC, bil_food_id ASC',
    );
    return rows
        .map((row) => _readFood(row['bil_food_id'] as String))
        .toList(growable: false);
  }

  UnifiedFood _readFood(String id) {
    final food = _database.select(
      'SELECT * FROM food WHERE bil_food_id = ? LIMIT 1',
      <Object?>[id],
    ).single;
    final aliases = _database.select(
      'SELECT language, name FROM alias WHERE bil_food_id = ? ORDER BY alias_id',
      <Object?>[id],
    );
    final nutrients = _database.select(
      'SELECT bil_nutrient_id, amount FROM nutrient WHERE bil_food_id = ?',
      <Object?>[id],
    );
    final portions = _database.select(
      'SELECT amount, unit_code, gram_weight FROM portion WHERE bil_food_id = ? ORDER BY portion_id LIMIT 1',
      <Object?>[id],
    );
    final barcodes = _database.select(
      'SELECT normalized_gtin FROM barcode WHERE bil_food_id = ? ORDER BY confidence DESC, normalized_gtin LIMIT 1',
      <Object?>[id],
    );

    final nameEn = food['name_en'] as String?;
    final nameAr = food['name_ar'] as String?;
    final fallbackAlias = aliases
        .where((row) => row['language'] == 'en')
        .firstOrNull;
    final resolvedName = (nameEn?.trim().isNotEmpty ?? false)
        ? nameEn!.trim()
        : (fallbackAlias?['name'] as String? ?? id);
    final serving = portions.isEmpty
        ? const FoodServing(amount: 100, unit: 'g', grams: 100)
        : FoodServing(
            amount: (portions.single['amount'] as num).toDouble(),
            unit: portions.single['unit_code'] as String,
            grams: ((portions.single['gram_weight'] as num?) ?? 100).toDouble(),
          );
    final nutrientMap = <FoodNutrient, NutrientAmount>{};
    for (final row in nutrients) {
      final nutrient = _mapNutrient(row['bil_nutrient_id'] as String);
      if (nutrient != null) {
        nutrientMap[nutrient] = NutrientAmount.known(
          (row['amount'] as num).toDouble(),
        );
      }
    }
    final kind = (food['food_kind'] as String).toLowerCase();
    final source = kind == 'branded'
        ? FoodDataSource.branded
        : FoodDataSource.foundation;
    return UnifiedFood(
      id: id,
      name: resolvedName,
      arabicName: nameAr,
      category: kind,
      keywords: aliases
          .map((row) => row['name'] as String)
          .toList(growable: false),
      barcode: barcodes.isEmpty
          ? null
          : barcodes.single['normalized_gtin'] as String,
      serving: serving,
      nutrients: Map<FoodNutrient, NutrientAmount>.unmodifiable(nutrientMap),
      source: source,
      sourceLabel: 'bil-mobile-catalog',
      verified: (food['quality_score'] as num).toDouble() >= 75,
      isCustom: false,
      updatedAt: DateTime.tryParse(food['updated_at'] as String),
    );
  }

  FoodNutrient? _mapNutrient(String id) {
    final normalized = id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return switch (normalized) {
      'calories' ||
      'energy' ||
      'kcal' ||
      'usda1008' ||
      'usda2047' ||
      'usda2048' => FoodNutrient.calories,
      'protein' || 'usda1003' => FoodNutrient.protein,
      'carbohydrates' ||
      'carbohydrate' ||
      'carbs' ||
      'usda1005' => FoodNutrient.carbohydrates,
      'fat' || 'totalfat' || 'usda1004' => FoodNutrient.fat,
      'fiber' || 'fibre' || 'usda1079' => FoodNutrient.fiber,
      'sugar' ||
      'totalsugars' ||
      'usda2000' ||
      'usda1063' => FoodNutrient.sugar,
      'sodium' || 'usda1093' => FoodNutrient.sodium,
      'potassium' || 'usda1092' => FoodNutrient.potassium,
      'calcium' || 'usda1087' => FoodNutrient.calcium,
      'magnesium' || 'usda1090' => FoodNutrient.magnesium,
      'phosphorus' || 'usda1091' => FoodNutrient.phosphorus,
      'iron' || 'usda1089' => FoodNutrient.iron,
      'vitaminc' || 'usda1162' => FoodNutrient.vitaminC,
      _ => null,
    };
  }

  void _validateSchema() {
    const required = <String>{
      'catalog_metadata',
      'food',
      'alias',
      'nutrient',
      'portion',
      'barcode',
      'food_fts',
    };
    final rows = _database.select(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final actual = rows.map((row) => row['name'] as String).toSet();
    final missing = required.difference(actual);
    if (missing.isNotEmpty) {
      throw StateError(
        'Invalid BIL mobile catalog; missing tables: ${missing.join(', ')}',
      );
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('MobileCatalogFoodRepository is closed');
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
