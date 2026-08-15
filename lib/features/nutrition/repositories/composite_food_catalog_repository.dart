import '../domain/unified_food.dart';
import '../services/food_deduplication_engine.dart';
import '../services/food_foundation_integrity_engine.dart';
import '../services/food_migration_engine.dart';
import '../services/food_quality_engine.dart';
import '../services/offline_barcode_resolver.dart';
import '../services/offline_food_search_pipeline.dart';
import 'mobile_catalog_food_repository.dart';
import 'unified_food_repository.dart';
import 'usda_core_catalog_repository.dart';

/// One read authority over the bundled catalog and every verified optional
/// catalog pack. Results are deduplicated before leaving the repository.
class CompositeFoodCatalogRepository implements UnifiedFoodRepository {
  CompositeFoodCatalogRepository(List<UnifiedFoodRepository> repositories)
    : _repositories = List.unmodifiable(repositories);

  final List<UnifiedFoodRepository> _repositories;

  void close() {
    for (final repository in _repositories) {
      if (repository is MobileCatalogFoodRepository) repository.close();
      if (repository is UsdaCoreCatalogRepository) repository.close();
    }
  }

  @override
  Stream<List<UnifiedFood>> watchAll() => Stream.fromFuture(getAll());

  @override
  Future<List<UnifiedFood>> getAll() async {
    final foods = <UnifiedFood>[];
    for (final repository in _repositories) {
      foods.addAll(await repository.getAll());
    }
    return _uniqueFoods(foods);
  }

  @override
  Future<List<FoodSearchHit>> searchUnified(
    String query, {
    int limit = 50,
  }) async {
    final hits = <FoodSearchHit>[];
    for (final repository in _repositories) {
      hits.addAll(await repository.searchUnified(query, limit: limit));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    final seen = <String>{};
    return hits
        .where((hit) => seen.add(_identity(hit.food)))
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<UnifiedFood?> findById(String id) async {
    for (final repository in _repositories) {
      final food = await repository.findById(id);
      if (food != null) return food;
    }
    return null;
  }

  @override
  Future<UnifiedFood?> findByBarcode(String barcode) async =>
      (await resolveBarcode(barcode)).food;

  @override
  Future<BarcodeResolution> resolveBarcode(String barcode) async {
    final resolutions = <BarcodeResolution>[];
    for (final repository in _repositories) {
      resolutions.add(await repository.resolveBarcode(barcode));
    }
    final candidates = _uniqueFoods(
      resolutions.expand((resolution) => resolution.candidates),
    );
    final identity = resolutions.first.identity;
    final status = switch (candidates.length) {
      0 =>
        resolutions.any(
              (resolution) =>
                  resolution.status == BarcodeResolutionStatus.invalid,
            )
            ? BarcodeResolutionStatus.invalid
            : BarcodeResolutionStatus.notFound,
      1 => BarcodeResolutionStatus.resolved,
      _ => BarcodeResolutionStatus.ambiguous,
    };
    return BarcodeResolution(
      identity: identity,
      status: status,
      candidates: candidates,
    );
  }

  @override
  Future<List<FoodDuplicateCandidate>> findDuplicateCandidates(
    UnifiedFood incoming, {
    FoodDuplicateKind minimumKind = FoodDuplicateKind.possible,
    int limit = 20,
  }) async => FoodDeduplicationEngine.findCandidates(
    incoming: incoming,
    existing: await getAll(),
    minimumKind: minimumKind,
    limit: limit,
  );

  @override
  Future<List<FoodMigrationPlan>> auditMigration({int limit = 1000}) async =>
      const <FoodMigrationPlan>[];

  @override
  Future<FoodQualityAudit> auditQuality({
    FoodConfidenceLevel? maximumConfidence,
    FoodQualityIssue? issue,
    int limit = 1000,
  }) async => FoodQualityAuditEngine.audit(
    (await getAll()).take(limit),
    maximumConfidence: maximumConfidence,
    issue: issue,
    limit: limit,
  );

  @override
  Future<FoodFoundationIntegrityReport> auditFoundationIntegrity({
    int migrationLimit = 1000,
    int duplicatePairLimit = 10000,
  }) async => FoodFoundationIntegrityEngine.audit(
    await getAll(),
    migrationLimit: migrationLimit,
    duplicatePairLimit: duplicatePairLimit,
  );

  List<UnifiedFood> _uniqueFoods(Iterable<UnifiedFood> foods) {
    final byIdentity = <String, UnifiedFood>{};
    for (final food in foods) {
      byIdentity.putIfAbsent(_identity(food), () => food);
    }
    return byIdentity.values.toList(growable: false);
  }

  String _identity(UnifiedFood food) => food.barcode?.trim().isNotEmpty == true
      ? 'barcode:${food.barcode}'
      : '${food.name.trim().toLowerCase()}|${food.serving.grams}';
}
