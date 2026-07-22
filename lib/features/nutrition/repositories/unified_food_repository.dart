import '../domain/unified_food.dart';
import '../services/offline_food_search_pipeline.dart';

abstract interface class UnifiedFoodRepository {
  Stream<List<UnifiedFood>> watchAll();
  Future<List<UnifiedFood>> getAll();
  Future<List<FoodSearchHit>> searchUnified(String query, {int limit = 50});
  Future<UnifiedFood?> findById(String id);
  Future<UnifiedFood?> findByBarcode(String barcode);
}
