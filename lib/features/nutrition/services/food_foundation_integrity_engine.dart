import '../domain/unified_food.dart';
import 'food_deduplication_engine.dart';
import 'food_migration_engine.dart';
import 'food_quality_engine.dart';
import 'food_search_normalizer.dart';

class FoodSourceDistribution {
  final int foundation;
  final int legacy;
  final int branded;
  final int custom;
  final int unknown;

  const FoodSourceDistribution({
    required this.foundation,
    required this.legacy,
    required this.branded,
    required this.custom,
    required this.unknown,
  });

  int countFor(FoodDataSource source) => switch (source) {
    FoodDataSource.foundation => foundation,
    FoodDataSource.legacy => legacy,
    FoodDataSource.branded => branded,
    FoodDataSource.custom => custom,
    FoodDataSource.unknown => unknown,
  };
}

class FoodFoundationIntegrityReport {
  final int totalFoods;
  final FoodSourceDistribution sources;
  final FoodQualityAudit quality;
  final List<FoodMigrationPlan> migrationPlans;
  final int exactBarcodeCollisionGroups;
  final int possibleDuplicatePairs;

  const FoodFoundationIntegrityReport({
    required this.totalFoods,
    required this.sources,
    required this.quality,
    required this.migrationPlans,
    required this.exactBarcodeCollisionGroups,
    required this.possibleDuplicatePairs,
  });

  bool get hasUnknownSources => sources.unknown > 0;
  bool get hasMigrationWork => migrationPlans.isNotEmpty;
  bool get hasBarcodeCollisions => exactBarcodeCollisionGroups > 0;
}

class FoodFoundationIntegrityEngine {
  const FoodFoundationIntegrityEngine._();

  static FoodFoundationIntegrityReport audit(
    Iterable<UnifiedFood> foods, {
    int migrationLimit = 1000,
    int duplicatePairLimit = 10000,
  }) {
    final all = List<UnifiedFood>.unmodifiable(foods);
    final counts = <FoodDataSource, int>{
      for (final source in FoodDataSource.values) source: 0,
    };
    for (final food in all) {
      counts[food.source] = counts[food.source]! + 1;
    }

    final barcodeGroups = <String, int>{};
    for (final food in all) {
      final barcode = FoodSearchNormalizer.normalizeBarcode(food.barcode ?? '');
      if (barcode.isEmpty) continue;
      barcodeGroups[barcode] = (barcodeGroups[barcode] ?? 0) + 1;
    }

    var duplicatePairs = 0;
    if (duplicatePairLimit > 0) {
      outer:
      for (var leftIndex = 0; leftIndex < all.length; leftIndex++) {
        for (
          var rightIndex = leftIndex + 1;
          rightIndex < all.length;
          rightIndex++
        ) {
          final assessment = FoodDeduplicationEngine.compare(
            all[leftIndex],
            all[rightIndex],
          );
          if (assessment.kind != FoodDuplicateKind.none ||
              _isCanonicalDuplicateFallback(all[leftIndex], all[rightIndex])) {
            duplicatePairs++;
            if (duplicatePairs >= duplicatePairLimit) break outer;
          }
        }
      }
    }

    return FoodFoundationIntegrityReport(
      totalFoods: all.length,
      sources: FoodSourceDistribution(
        foundation: counts[FoodDataSource.foundation]!,
        legacy: counts[FoodDataSource.legacy]!,
        branded: counts[FoodDataSource.branded]!,
        custom: counts[FoodDataSource.custom]!,
        unknown: counts[FoodDataSource.unknown]!,
      ),
      quality: FoodQualityAuditEngine.audit(all),
      migrationPlans: FoodMigrationEngine.auditAll(all, limit: migrationLimit),
      exactBarcodeCollisionGroups: barcodeGroups.values
          .where((count) => count > 1)
          .length,
      possibleDuplicatePairs: duplicatePairs,
    );
  }

  static bool _isCanonicalDuplicateFallback(
    UnifiedFood left,
    UnifiedFood right,
  ) {
    final leftName = FoodSearchNormalizer.normalize(left.name);
    final rightName = FoodSearchNormalizer.normalize(right.name);
    if (leftName.isEmpty || leftName != rightName) return false;

    final servingReference = left.serving.grams > right.serving.grams
        ? left.serving.grams
        : right.serving.grams;
    if (!servingReference.isFinite || servingReference <= 0) return false;
    final servingDifference = (left.serving.grams - right.serving.grams).abs();
    if (servingDifference / servingReference > 0.02) return false;

    const nutrients = <FoodNutrient>[
      FoodNutrient.calories,
      FoodNutrient.protein,
      FoodNutrient.carbohydrates,
      FoodNutrient.fat,
    ];
    var compared = 0;
    for (final nutrient in nutrients) {
      final leftValue = left.knownValue(nutrient);
      final rightValue = right.knownValue(nutrient);
      if (leftValue == null || rightValue == null) continue;
      final reference = leftValue.abs() > rightValue.abs()
          ? leftValue.abs()
          : rightValue.abs();
      final relativeDifference = reference == 0
          ? 0.0
          : (leftValue - rightValue).abs() / reference;
      if (relativeDifference > 0.05) return false;
      compared++;
    }
    return compared > 0;
  }
}
