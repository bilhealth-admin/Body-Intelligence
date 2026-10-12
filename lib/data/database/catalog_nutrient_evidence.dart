import 'dart:convert';

import '../../features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'app_database.dart';
import 'nutrient_evidence.dart';

/// An attributed, unit-bearing food basis. ml/serving never become grams.
class CatalogNutrientEvidence {
  const CatalogNutrientEvidence(this.row, this.nutrients, this.ownerKey);
  static const schema = 'bil.catalog.nutrition.v1';
  final Food row;
  final CoachFoodNutrients nutrients;
  final String? ownerKey;

  static double rawValue(Food row, FoodNutrient n) => switch (n) {
    FoodNutrient.calories => row.calories,
    FoodNutrient.protein => row.protein,
    FoodNutrient.carbohydrates => row.carbs,
    FoodNutrient.fat => row.fats,
    FoodNutrient.fiber => row.fiber,
    FoodNutrient.sugar => row.sugar,
    FoodNutrient.sodium => row.sodium,
    FoodNutrient.potassium => row.potassium,
    FoodNutrient.calcium => row.calcium,
    FoodNutrient.magnesium => row.magnesium,
    FoodNutrient.phosphorus => row.phosphorus,
    FoodNutrient.iron => row.iron,
    FoodNutrient.vitaminC => row.vitaminC,
    _ => 0,
  };

  static String encode(
    Food row,
    Map<FoodNutrient, double?> incoming, {
    String? ownerKey,
  }) {
    double? prior(FoodNutrient n) {
      final raw = rawValue(row, n);
      if (raw == 0 || !raw.isFinite || raw < 0) return null;
      if (n == FoodNutrient.iron || n == FoodNutrient.vitaminC) return raw;
      final tracked = TrackedNutrient.values
          .where(
            (value) => switch (value) {
              TrackedNutrient.calories => n == FoodNutrient.calories,
              TrackedNutrient.protein => n == FoodNutrient.protein,
              TrackedNutrient.carbohydrates => n == FoodNutrient.carbohydrates,
              TrackedNutrient.fat => n == FoodNutrient.fat,
              _ => value.name == n.name,
            },
          )
          .firstOrNull;
      return tracked != null &&
              NutrientEvidenceMask.isKnown(
                mask: row.nutrientEvidenceMask,
                source: row.source,
                nutrient: tracked,
                value: raw,
              )
          ? raw
          : null;
    }

    final nutrients = CoachFoodNutrients({
      for (final n in FoodNutrient.values) n: incoming[n] ?? prior(n),
    });
    return jsonEncode({
      'schema': schema,
      'id': row.uuid,
      'name': row.name,
      'source': row.source,
      'verified': row.verified,
      'basisQuantity': row.servingSize,
      'basisUnit': row.servingUnit,
      'ownerKey': ownerKey,
      'mask': row.nutrientEvidenceMask,
      'nutrients': nutrients.toJson(),
    });
  }

  factory CatalogNutrientEvidence.decode(
    Food row,
    Map data, {
    String? expectedOwner,
  }) {
    const keys = {
      'schema',
      'id',
      'name',
      'source',
      'verified',
      'basisQuantity',
      'basisUnit',
      'ownerKey',
      'mask',
      'nutrients',
    };
    if (data.length != keys.length ||
        !keys.every(data.containsKey) ||
        data['schema'] != schema ||
        data['id'] != row.uuid ||
        data['name'] != row.name ||
        data['source'] != row.source ||
        data['verified'] != row.verified ||
        data['basisQuantity'] != row.servingSize ||
        data['basisUnit'] != row.servingUnit ||
        data['mask'] != row.nutrientEvidenceMask ||
        (data['ownerKey'] != null && data['ownerKey'] is! String) ||
        (expectedOwner != null &&
            data['ownerKey'] != null &&
            data['ownerKey'] != expectedOwner)) {
      throw const FormatException('Catalog nutrient identity mismatch.');
    }
    final nutrients = CoachFoodNutrients.fromJson(data['nutrients']);
    for (final n in FoodNutrient.values.where(
      (n) => n.index <= FoodNutrient.vitaminC.index,
    )) {
      final expected = nutrients[n] ?? 0, raw = rawValue(row, n);
      if (!raw.isFinite ||
          (raw - expected).abs() > 1e-9 * (1 + expected.abs())) {
        throw const FormatException('Catalog nutrient projection mismatch.');
      }
    }
    return CatalogNutrientEvidence(row, nutrients, data['ownerKey'] as String?);
  }

  /// Explicit mass units only; volume/count need their own unit-based journey.
  double? get basisGrams => switch (row.servingUnit.toLowerCase()) {
    'g' => row.servingSize,
    'mg' => row.servingSize / 1000,
    'kg' => row.servingSize * 1000,
    'oz' => row.servingSize * 28.349523125,
    'lb' => row.servingSize * 453.59237,
    _ => null,
  };
  CoachFoodSnapshot? get snapshot => basisGrams == null
      ? null
      : CoachFoodSnapshot(
          identity: row.uuid,
          name: row.name,
          preparedState: 'source-state-unspecified',
          basisGrams: basisGrams!,
          nutrients: nutrients,
          source: CoachFoodSourceEvidence(
            kind: row.isCustom
                ? CoachFoodSourceKind.userFixed
                : CoachFoodSourceKind.reference,
            ref: row.source,
            revision: row.updatedAt.toUtc().toIso8601String(),
            ownerKey: ownerKey,
          ),
        );
}
