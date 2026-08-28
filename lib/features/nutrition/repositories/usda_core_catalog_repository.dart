import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

import '../domain/barcode_identity.dart';
import '../domain/unified_food.dart';
import '../services/food_deduplication_engine.dart';
import '../services/food_foundation_integrity_engine.dart';
import '../services/food_migration_engine.dart';
import '../services/food_quality_engine.dart';
import '../services/food_search_normalizer.dart';
import '../services/food_search_assistance.dart';
import '../services/offline_barcode_resolver.dart';
import '../services/offline_food_search_pipeline.dart';
import 'unified_food_repository.dart';

/// Read-only adapter for the compact USDA Offline Core catalog.
///
/// Schema:
/// - foods
/// - food_fts
/// - portions
/// - search_alias
/// - catalog_metadata
class UsdaCoreCatalogRepository implements UnifiedFoodRepository {
  static const FoodSearchAssistance _assistance = FoodSearchAssistance();
  final Database _database;
  final bool _ownsDatabase;
  bool _closed = false;

  UsdaCoreCatalogRepository.open(String path)
    : _database = sqlite3.open(path, mode: OpenMode.readOnly),
      _ownsDatabase = true {
    _validateSchema();
  }

  UsdaCoreCatalogRepository.fromDatabase(
    this._database, {
    this._ownsDatabase = false,
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

  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsDatabase) _database.close();
  }

  @override
  Stream<List<UnifiedFood>> watchAll() =>
      Stream<List<UnifiedFood>>.fromFuture(getAll());

  @override
  Future<List<UnifiedFood>> getAll() async {
    _ensureOpen();
    final rows = _database.select(
      'SELECT fdc_id FROM foods '
      'ORDER BY source_dataset, normalized_description LIMIT 5000',
    );
    return List<UnifiedFood>.unmodifiable(
      rows.map((row) => _readFood((row['fdc_id'] as num).toInt())),
    );
  }

  @override
  Future<UnifiedFood?> findById(String id) async {
    _ensureOpen();
    final fdcId = _parseId(id);
    if (fdcId == null) return null;
    final rows = _database.select(
      'SELECT fdc_id FROM foods WHERE fdc_id = ? LIMIT 1',
      <Object?>[fdcId],
    );
    return rows.isEmpty ? null : _readFood(fdcId);
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
      final rows = _database.select(
        'SELECT fdc_id FROM foods '
        "ORDER BY CASE source_dataset "
        "WHEN 'foundation' THEN 0 WHEN 'sr_legacy' THEN 1 ELSE 2 END, "
        'normalized_description LIMIT ?',
        <Object?>[limit],
      );
      return List<FoodSearchHit>.unmodifiable(
        rows.map(
          (row) => FoodSearchHit(
            food: _readFood((row['fdc_id'] as num).toInt()),
            score: 1,
            reasons: const <String>['usda-core-order'],
          ),
        ),
      );
    }

    final terms = <String>{..._assistance.expand(query)};
    final aliasRows = _database.select(
      'SELECT target_term FROM search_alias '
      'WHERE normalized_alias = ? OR normalized_alias LIKE ? '
      'ORDER BY length(normalized_alias), normalized_alias LIMIT 32',
      <Object?>[normalized, '$normalized%'],
    );
    for (final row in aliasRows) {
      final term = (row['target_term'] as String?)?.trim();
      if (term != null && term.isNotEmpty) terms.add(term);
    }

    final ftsClauses = terms
        .map(_ftsExpression)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (ftsClauses.isEmpty) return const <FoodSearchHit>[];

    final ftsQuery = ftsClauses.map((value) => '($value)').join(' OR ');
    final rows = _database.select(
      'SELECT f.fdc_id, bm25(food_fts) AS rank '
      'FROM food_fts '
      'JOIN foods f ON f.fdc_id = food_fts.rowid '
      'WHERE food_fts MATCH ? '
      // FoodData Central contains component/derivation rows whose names are
      // searchable but whose core macro columns are intentionally null. They
      // are useful source records, not usable diary candidates. Runtime
      // search materializes every returned row for diary compatibility, so
      // exclude incomplete rows instead of persisting misleading all-zero
      // records beside the complete food the user actually reviewed.
      'AND f.energy_kcal IS NOT NULL '
      'AND f.protein_g IS NOT NULL '
      'AND f.carbs_g IS NOT NULL '
      'AND f.fat_g IS NOT NULL '
      'ORDER BY '
      "CASE f.source_dataset "
      "WHEN 'foundation' THEN 0 WHEN 'sr_legacy' THEN 1 ELSE 2 END, "
      'rank ASC, f.normalized_description ASC LIMIT ?',
      <Object?>[ftsQuery, limit],
    );

    return List<FoodSearchHit>.unmodifiable(
      rows.map(
        (row) => FoodSearchHit(
          food: _readFood((row['fdc_id'] as num).toInt()),
          score: 1000 - ((row['rank'] as num?)?.toDouble() ?? 0),
          reasons: terms.length > 1
              ? const <String>['sqlite-fts', 'arabic-query-expansion']
              : const <String>['sqlite-fts'],
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
      'SELECT fdc_id FROM foods WHERE barcode = ? LIMIT 10',
      <Object?>[identity.digits],
    );
    final candidates = rows
        .map((row) => _readFood((row['fdc_id'] as num).toInt()))
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
    final hits = await searchUnified(incoming.name, limit: limit * 2);
    return List<FoodDuplicateCandidate>.unmodifiable(
      FoodDeduplicationEngine.findCandidates(
        incoming: incoming,
        existing: hits.map((hit) => hit.food),
        minimumKind: minimumKind,
        limit: limit,
      ),
    );
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
    (await getAll()).take(migrationLimit),
    migrationLimit: migrationLimit,
    duplicatePairLimit: duplicatePairLimit,
  );

  UnifiedFood _readFood(int fdcId) {
    final row = _database.select(
      'SELECT * FROM foods WHERE fdc_id = ? LIMIT 1',
      <Object?>[fdcId],
    ).single;

    final portionRows = _database.select(
      'SELECT amount, unit, portion_description, modifier, gram_weight '
      'FROM portions WHERE fdc_id = ? '
      'ORDER BY sequence_number, id LIMIT 1',
      <Object?>[fdcId],
    );

    final serving = portionRows.isEmpty
        ? const FoodServing(amount: 100, unit: 'g', grams: 100)
        : _servingFrom(portionRows.single);

    final sourceDataset = row['source_dataset'] as String;
    final source = switch (sourceDataset) {
      'foundation' => FoodDataSource.foundation,
      'sr_legacy' => FoodDataSource.legacy,
      'fndds' => FoodDataSource.foundation,
      'branded' => FoodDataSource.branded,
      _ => FoodDataSource.unknown,
    };

    final nutrients = <FoodNutrient, NutrientAmount>{};
    _put(nutrients, FoodNutrient.calories, row['energy_kcal']);
    _put(nutrients, FoodNutrient.protein, row['protein_g']);
    _put(nutrients, FoodNutrient.carbohydrates, row['carbs_g']);
    _put(nutrients, FoodNutrient.fat, row['fat_g']);
    _put(nutrients, FoodNutrient.fiber, row['fiber_g']);
    _put(nutrients, FoodNutrient.sugar, row['sugars_g']);
    _put(nutrients, FoodNutrient.sodium, row['sodium_mg']);
    _put(nutrients, FoodNutrient.potassium, row['potassium_mg']);
    _put(nutrients, FoodNutrient.calcium, row['calcium_mg']);
    _put(nutrients, FoodNutrient.iron, row['iron_mg']);
    final hasDiaryCoreEvidence = const <FoodNutrient>[
      FoodNutrient.calories,
      FoodNutrient.protein,
      FoodNutrient.carbohydrates,
      FoodNutrient.fat,
    ].every((nutrient) => nutrients[nutrient]?.isKnown == true);

    final brand = (row['brand_name'] as String?)?.trim();
    final owner = (row['brand_owner'] as String?)?.trim();
    final category = (row['branded_category'] as String?)?.trim();

    return UnifiedFood(
      id: 'usda:$fdcId',
      name: row['description'] as String,
      arabicName: _assistance.arabicNameFor(row['description'] as String),
      category: category?.isNotEmpty == true ? category : sourceDataset,
      keywords: <String>[
        if (brand?.isNotEmpty == true) brand!,
        if (owner?.isNotEmpty == true) owner!,
        sourceDataset,
      ],
      barcode: (row['barcode'] as String?)?.trim(),
      serving: serving,
      nutrients: Map<FoodNutrient, NutrientAmount>.unmodifiable(nutrients),
      source: source,
      sourceLabel: 'USDA FoodData Central — $sourceDataset',
      verified: sourceDataset != 'branded' && hasDiaryCoreEvidence,
      isCustom: false,
      updatedAt: DateTime.tryParse(row['publication_date'] as String? ?? ''),
    );
  }

  FoodServing _servingFrom(Row row) {
    final grams = (row['gram_weight'] as num?)?.toDouble();
    final amount = (row['amount'] as num?)?.toDouble();
    final unit = (row['unit'] as String?)?.trim();
    return FoodServing(
      amount: amount != null && amount > 0 ? amount : 100,
      unit: unit?.isNotEmpty == true ? unit! : 'g',
      grams: grams != null && grams > 0 ? grams : 100,
    );
  }

  void _put(
    Map<FoodNutrient, NutrientAmount> target,
    FoodNutrient nutrient,
    Object? raw,
  ) {
    if (raw is num) {
      target[nutrient] = NutrientAmount.known(raw.toDouble());
    }
  }

  int? _parseId(String id) {
    final normalized = id.trim();
    final raw = normalized.startsWith('usda:')
        ? normalized.substring('usda:'.length)
        : normalized;
    return int.tryParse(raw);
  }

  String _ftsExpression(String term) {
    return term
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => '"${token.replaceAll('"', '""')}"*')
        .join(' AND ');
  }

  void _validateSchema() {
    const required = <String>{
      'catalog_metadata',
      'foods',
      'food_fts',
      'portions',
      'search_alias',
    };
    final rows = _database.select(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final actual = rows.map((row) => row['name'] as String).toSet();
    final missing = required.difference(actual);
    if (missing.isNotEmpty) {
      throw StateError(
        'Invalid USDA Core catalog; missing tables: ${missing.join(', ')}',
      );
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('USDA Core catalog is closed');
  }
}
