import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/food_basis_evidence.dart';
import '../../nutrition/adapters/unified_food_adapter.dart';
import '../../nutrition/domain/unified_food.dart' show FoodDataSource;
import '../domain/food_v2/coach_food_v2.dart';

/// A normalized row fetched independently from the existing local catalog.
///
/// This is an adapter boundary, not proof that an arbitrary [Food] is trusted.
/// Callers must supply the actual repository result selected by the user, never
/// a row reconstructed from a model, photo response, or barcode payload. This
/// adapter opens no repository and cannot persist a meal or grant verification.
final class CoachMediaCatalogEntry {
  const CoachMediaCatalogEntry._({
    required this.row,
    required this.food,
    required this.unitRule,
  });

  /// Retained for the existing food-match selection dialog.
  final Food row;
  final CoachFoodSnapshot food;
  final CoachFoodUnitRule? unitRule;

  /// [ownerKey] is LocalDatabaseScope.keyForOwner(database.localOwnerId),
  /// rather than the raw authentication identifier. The caller separately
  /// guards owner/request/epoch changes across asynchronous operations.
  ///
  /// Missing, corrupt, estimated, foreign-owner or unsupported source evidence
  /// remains unresolved. A legacy volume/count serving never implies a density
  /// or item weight. Optional rules must already have trusted local provenance.
  static CoachMediaCatalogEntry? fromLocalFood(
    Food row, {
    required String ownerKey,
    CoachFoodUnitRule? unitRule,
  }) {
    if (!_boundedText(ownerKey, 128) ||
        ownerKey != ownerKey.trim() ||
        row.id <= 0 ||
        row.revision <= 0 ||
        row.revision > 9007199254740991 ||
        row.deletedAt != null ||
        !_boundedText(row.uuid, 128) ||
        row.uuid != row.uuid.trim() ||
        !_boundedText(row.name, 240) ||
        !_boundedText(row.source, 200) ||
        !_boundedText(row.servingUnit, 32) ||
        row.nutrientEvidenceMask < 0) {
      return null;
    }
    try {
      final evidence = FoodBasisEvidence.read(row, ownerKey: ownerKey);
      if (!evidence.isValid) return null;
      final food = evidence.isModern ? evidence.snapshot : _legacySnapshot(row);
      if (food == null ||
          !_sourceMatchesOwner(food.source, ownerKey) ||
          (unitRule != null &&
              (unitRule.identity != food.identity ||
                  unitRule.preparedState != food.preparedState ||
                  !_sourceMatchesOwner(unitRule.source, ownerKey)))) {
        return null;
      }
      return CoachMediaCatalogEntry._(row: row, food: food, unitRule: unitRule);
    } on CoachFoodContractError {
      return null;
    } on JsonUnsupportedObjectError {
      return null;
    }
  }

  static CoachFoodSnapshot? _legacySnapshot(Food row) {
    if (!row.verified || row.isCustom) return null;
    final adapted = const UnifiedFoodAdapter().adapt(row);
    // The installed mobile catalog uses this exact persisted source label.
    // Its broad legacy enum is unknown; the actual repository label remains
    // sufficient here without inventing a USDA or other upstream identity.
    final mobileCatalog = row.source == 'bil-mobile-catalog';
    if (!mobileCatalog &&
        adapted.source != FoodDataSource.foundation &&
        adapted.source != FoodDataSource.branded) {
      return null;
    }
    final grams = adapted.serving.grams;
    if (!grams.isFinite || grams < .001 || grams > 100000) return null;
    final nutrients = CoachFoodNutrients({
      for (final nutrient in FoodNutrient.values)
        nutrient: adapted.knownValue(nutrient),
    });
    final identity = 'local-food:${row.uuid}';
    const preparation = 'as-listed-in-local-catalog';
    final sourceKind = adapted.source == FoodDataSource.branded
        ? CoachFoodSourceKind.label
        : CoachFoodSourceKind.reference;
    // Bind a stable snapshot revision to both the stored row revision and its
    // actual evidence. A catalog value edit is detectable even if a legacy
    // importer forgets to increment revision or updatedAt.
    final revision = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'identity': identity,
              'localId': row.id,
              'rowRevision': row.revision,
              'updatedAt': row.updatedAt.toUtc().toIso8601String(),
              'name': row.name,
              'source': row.source,
              'sourceKind': sourceKind.wireName,
              'preparedState': preparation,
              'servingSize': row.servingSize,
              'servingUnit': row.servingUnit,
              'basisGrams': grams,
              'nutrientEvidenceMask': row.nutrientEvidenceMask,
              'nutrients': nutrients.toJson(),
              'verified': row.verified,
              'isCustom': row.isCustom,
            }),
          ),
        )
        .toString();
    return CoachFoodSnapshot(
      identity: identity,
      name: row.name,
      // Legacy rows have no separate preparation field. This records exactly
      // that limitation; a model's raw/cooked guess never fills the gap.
      preparedState: preparation,
      basisGrams: grams,
      nutrients: nutrients,
      source: CoachFoodSourceEvidence(
        kind: sourceKind,
        ref: '$identity;source:${row.source}',
        revision: 'local-r${row.revision}:$revision',
      ),
    );
  }

  static bool _sourceMatchesOwner(
    CoachFoodSourceEvidence source,
    String ownerKey,
  ) =>
      source.kind != CoachFoodSourceKind.estimated &&
      (source.ownerKey == null || source.ownerKey == ownerKey);

  static bool _boundedText(String value, int maximum) =>
      value.trim().isNotEmpty &&
      value.runes.length <= maximum &&
      !value.runes.any((rune) => rune < 32 || rune == 127);
}
