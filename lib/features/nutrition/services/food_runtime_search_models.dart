import '../../../data/database/app_database.dart';
import '../domain/product_identity.dart';
import '../repositories/unified_food_repository.dart';
import '../domain/unified_food.dart';

typedef MobileCatalogRepositoryResolver =
    Future<UnifiedFoodRepository?> Function();
typedef CommunityFoodSearchResolver =
    Future<List<UnifiedFood>> Function(String query, {int limit});

enum FoodRuntimeSearchSource { localOnly, catalogAndLocal, localFallback }

enum FoodRuntimeBarcodeStatus {
  invalid,
  found,
  identifiedProduct,
  notFound,
  degraded,
}

class FoodRuntimeBarcodeResult {
  final FoodRuntimeBarcodeStatus status;
  final List<Food> foods;
  final FoodRuntimeSearchSource source;
  final String normalizedBarcode;
  final ProductIdentity? product;
  final String? ingredients;

  const FoodRuntimeBarcodeResult({
    required this.status,
    required this.foods,
    required this.source,
    required this.normalizedBarcode,
    this.product,
    this.ingredients,
  });

  bool get found => status == FoodRuntimeBarcodeStatus.found;
  bool get invalid => status == FoodRuntimeBarcodeStatus.invalid;
  bool get degraded => status == FoodRuntimeBarcodeStatus.degraded;
}

class FoodRuntimeSearchResult {
  final List<Food> foods;
  final FoodRuntimeSearchSource source;

  const FoodRuntimeSearchResult({required this.foods, required this.source});

  bool get catalogUsed => source == FoodRuntimeSearchSource.catalogAndLocal;

  bool get degraded => source == FoodRuntimeSearchSource.localFallback;
}
