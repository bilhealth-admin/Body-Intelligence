import 'food_image.dart';
import '../../../data/database/nutrient_evidence.dart';

enum FoodDataSource { foundation, legacy, branded, custom, unknown }

enum FoodNutrient {
  calories,
  protein,
  carbohydrates,
  fat,
  fiber,
  sugar,
  sodium,
  potassium,
  calcium,
  magnesium,
  iron,
  vitaminC,
}

class NutrientAmount {
  final double value;
  final bool isKnown;

  const NutrientAmount.known(this.value) : isKnown = true;
  const NutrientAmount.missing() : value = 0, isKnown = false;

  double? get nullableValue => isKnown ? value : null;
}

class FoodServing {
  final double amount;
  final String unit;
  final double grams;

  const FoodServing({
    required this.amount,
    required this.unit,
    required this.grams,
  });
}

class UnifiedFood {
  final String id;
  final int? localId;
  final String name;
  final String? arabicName;
  final String? category;
  final List<String> keywords;
  final String? barcode;
  final FoodServing serving;
  final Map<FoodNutrient, NutrientAmount> nutrients;
  final FoodDataSource source;
  final String sourceLabel;
  final bool verified;
  final bool isCustom;
  final DateTime? updatedAt;
  final List<FoodImageReference> images;

  const UnifiedFood({
    required this.id,
    this.localId,
    required this.name,
    this.arabicName,
    this.category,
    this.keywords = const <String>[],
    this.barcode,
    required this.serving,
    required this.nutrients,
    required this.source,
    required this.sourceLabel,
    required this.verified,
    required this.isCustom,
    this.updatedAt,
    this.images = const <FoodImageReference>[],
  });

  NutrientAmount nutrient(FoodNutrient nutrient) =>
      nutrients[nutrient] ?? const NutrientAmount.missing();

  double? knownValue(FoodNutrient nutrient) =>
      nutrientValue(nutrient).nullableValue;

  NutrientAmount nutrientValue(FoodNutrient nutrient) =>
      this.nutrient(nutrient);

  bool hasEvidence(FoodNutrient nutrient) => this.nutrient(nutrient).isKnown;

  String get preferredDisplayName =>
      arabicName?.trim().isNotEmpty == true ? arabicName!.trim() : name.trim();

  static FoodDataSource parseSource({
    required String source,
    required bool isCustom,
  }) {
    if (isCustom) return FoodDataSource.custom;
    switch (source.trim().toLowerCase()) {
      case 'foundation':
      case 'starter':
      case 'local':
        return FoodDataSource.foundation;
      case 'legacy':
        return FoodDataSource.legacy;
      case 'branded':
      case 'brand':
        return FoodDataSource.branded;
      default:
        return FoodDataSource.unknown;
    }
  }

  static bool evidenceFromMask(int mask, FoodNutrient nutrient) {
    return switch (nutrient) {
      FoodNutrient.fiber => NutrientEvidenceMask.contains(
        mask,
        TrackedNutrient.fiber,
      ),
      FoodNutrient.sugar => NutrientEvidenceMask.contains(
        mask,
        TrackedNutrient.sugar,
      ),
      FoodNutrient.sodium => NutrientEvidenceMask.contains(
        mask,
        TrackedNutrient.sodium,
      ),
      FoodNutrient.potassium => NutrientEvidenceMask.contains(
        mask,
        TrackedNutrient.potassium,
      ),
      FoodNutrient.calcium => NutrientEvidenceMask.contains(
        mask,
        TrackedNutrient.calcium,
      ),
      FoodNutrient.magnesium => NutrientEvidenceMask.contains(
        mask,
        TrackedNutrient.magnesium,
      ),
      _ => true,
    };
  }
}
