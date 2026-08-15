import '../../../data/database/app_database.dart';
import '../domain/barcode_identity.dart';
import '../domain/product_identity.dart';
import '../domain/unified_food.dart';
import 'food_search_normalizer.dart';

/// Fail-closed contract applied before a barcode candidate can be offered as
/// food. A matching number alone is not nutrition provenance.
class BarcodeFoodContract {
  const BarcodeFoodContract._();

  static bool acceptsLocal(Food food, BarcodeIdentity identity) {
    return identity.isValid &&
        FoodSearchNormalizer.normalizeBarcode(food.barcode ?? '') ==
            identity.digits &&
        food.name.trim().isNotEmpty &&
        food.source.trim().isNotEmpty &&
        food.servingSize > 0 &&
        food.servingUnit.trim().isNotEmpty;
  }

  static bool acceptsUnified(UnifiedFood food, BarcodeIdentity identity) {
    return identity.isValid &&
        FoodSearchNormalizer.normalizeBarcode(food.barcode ?? '') ==
            identity.digits &&
        food.name.trim().isNotEmpty &&
        food.sourceLabel.trim().isNotEmpty &&
        food.serving.amount > 0 &&
        food.serving.grams > 0 &&
        food.serving.unit.trim().isNotEmpty &&
        food.nutrient(FoodNutrient.calories).isKnown;
  }

  static bool canMaterializeProduct(ProductIdentity? product) =>
      product != null &&
      product.hasNutritionUse &&
      product.source.trim().isNotEmpty;

  static List<Food> deduplicateLocal(
    Iterable<Food> foods,
    BarcodeIdentity identity,
  ) {
    final byEvidence = <String, Food>{};
    for (final food in foods.where((food) => acceptsLocal(food, identity))) {
      final key = <String>[
        FoodSearchNormalizer.normalizeBarcode(food.barcode ?? ''),
        FoodSearchNormalizer.normalize(food.name),
        food.servingSize.toStringAsFixed(4),
        food.servingUnit.trim().toLowerCase(),
        food.source.trim().toLowerCase(),
      ].join('|');
      final current = byEvidence[key];
      if (current == null || (!current.verified && food.verified)) {
        byEvidence[key] = food;
      }
    }
    final result = byEvidence.values.toList(growable: false)
      ..sort((a, b) {
        final verified = (b.verified ? 1 : 0).compareTo(a.verified ? 1 : 0);
        if (verified != 0) return verified;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return List<Food>.unmodifiable(result);
  }
}
