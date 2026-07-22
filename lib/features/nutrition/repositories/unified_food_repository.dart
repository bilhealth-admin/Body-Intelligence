import '../domain/unified_food.dart';
import '../services/food_deduplication_engine.dart';
import '../services/food_migration_engine.dart';
import '../services/food_quality_engine.dart';
import '../services/offline_food_search_pipeline.dart';

abstract interface class UnifiedFoodRepository {
  Stream<List<UnifiedFood>> watchAll();
  Future<List<UnifiedFood>> getAll();
  Future<List<FoodSearchHit>> searchUnified(String query, {int limit = 50});
  Future<UnifiedFood?> findById(String id);
  Future<UnifiedFood?> findByBarcode(String barcode);
  Future<List<FoodDuplicateCandidate>> findDuplicateCandidates(
    UnifiedFood incoming, {
    FoodDuplicateKind minimumKind = FoodDuplicateKind.possible,
    int limit = 20,
  });
  Future<List<FoodMigrationPlan>> auditMigration({int limit = 1000});
  Future<FoodQualityAudit> auditQuality({
    FoodConfidenceLevel? maximumConfidence,
    FoodQualityIssue? issue,
    int limit = 1000,
  });
}
