import '../../../data/database/app_database.dart';
import '../../../data/database/food_basis_evidence.dart';
import '../../../data/repositories/food_repository.dart';
import '../domain/food_v2/coach_food_v2.dart';

/// Conservative local-food adapter for AI Coach.
///
/// It never upgrades an arbitrary local row to reference/label authority. Only
/// provenance already encoded in the immutable Food V2 envelope or an
/// explicitly recognized historical source is admitted. Unknown nutrients
/// remain null through [FoodBasisEvidence].
final class CoachFoodCatalogAdapter {
  const CoachFoodCatalogAdapter(this._foods);

  final FoodRepository _foods;

  Future<List<CoachFoodCatalogEntry>> exactMatches(
    String concept, {
    required String ownerKey,
  }) async {
    final wanted = normalizeFoodConcept(concept);
    if (wanted.isEmpty) return const [];
    final rows = await _foods.getFoods();
    final exact = <CoachFoodCatalogEntry>[];
    final contained = <CoachFoodCatalogEntry>[];
    for (final row in rows) {
      final names = <String>{
        row.name,
        if (row.arabicName != null) row.arabicName!,
      };
      final normalized = names
          .map(normalizeFoodConcept)
          .where((v) => v.isNotEmpty);
      final entry = _entry(row, ownerKey: ownerKey);
      if (entry == null) continue;
      if (normalized.any((name) => name == wanted)) {
        exact.add(entry);
      } else if (wanted.length >= 3 &&
          normalized.any(
            (name) => name.contains(wanted) || wanted.contains(name),
          )) {
        contained.add(entry);
      }
    }
    return _dedupe(exact.isNotEmpty ? exact : contained);
  }

  static List<CoachFoodCatalogEntry> _dedupe(
    List<CoachFoodCatalogEntry> entries,
  ) {
    final byEvidence = <String, CoachFoodCatalogEntry>{};
    for (final entry in entries) {
      final snapshot = entry.snapshot;
      final key = snapshot == null
          ? 'row:${entry.row.uuid}'
          : 'snapshot:${snapshot.digest}';
      byEvidence.putIfAbsent(key, () => entry);
    }
    return List.unmodifiable(byEvidence.values);
  }

  CoachFoodCatalogEntry? _entry(Food row, {required String ownerKey}) {
    final evidence = FoodBasisEvidence.read(row, ownerKey: ownerKey);
    if (!evidence.isValid) return null;
    final modern = evidence.snapshot;
    if (modern != null) {
      return CoachFoodCatalogEntry(
        row: row,
        snapshot: modern,
        evidence: evidence,
      );
    }
    final kind = _legacyKind(row.source, row.category ?? '');
    if (kind == null) {
      // The values can still seed an explicitly approved Personal BIL rule, but
      // they cannot be used as an automatically trusted food proposal.
      return CoachFoodCatalogEntry(row: row, evidence: evidence);
    }
    if (row.servingUnit.trim().toLowerCase() != 'g' || row.servingSize <= 0) {
      return CoachFoodCatalogEntry(row: row, evidence: evidence);
    }
    return CoachFoodCatalogEntry(
      row: row,
      evidence: evidence,
      snapshot: CoachFoodSnapshot(
        identity: 'legacy-food:${row.uuid}',
        name: row.name,
        preparedState: 'as-recorded',
        basisGrams: row.servingSize,
        nutrients: CoachFoodNutrients(evidence.values),
        source: CoachFoodSourceEvidence(
          kind: kind,
          ref: row.source,
          revision:
              'food-row:${row.uuid}:${row.updatedAt.toUtc().toIso8601String()}',
        ),
      ),
    );
  }

  static CoachFoodSourceKind? _legacyKind(String source, String category) {
    final value =
        '${source.trim().toLowerCase()} ${category.trim().toLowerCase()}';
    if (value.contains('recipe-calculation:') ||
        value.contains('calculated-recipe') ||
        value.contains('calculated recipe')) {
      return CoachFoodSourceKind.calculatedRecipe;
    }
    if (value.contains('usda') ||
        value.contains('fooddata central') ||
        value.contains('fdc') ||
        value.contains('scientific catalog') ||
        value.contains('foundation')) {
      return CoachFoodSourceKind.reference;
    }
    if (value.contains('label') ||
        value.contains('barcode') ||
        value.contains('open food facts') ||
        value.contains('branded') ||
        value.contains('manufacturer')) {
      return CoachFoodSourceKind.label;
    }
    return null;
  }
}

final class CoachFoodCatalogEntry {
  const CoachFoodCatalogEntry({
    required this.row,
    required this.evidence,
    this.snapshot,
  });

  final Food row;
  final FoodBasisEvidence evidence;
  final CoachFoodSnapshot? snapshot;

  /// Freezes the exact row values under an explicit Personal BIL approval.
  /// A non-gram serving is admitted only when the approved rule supplies its
  /// documented mass conversion; the conversion changes the basis mass, not
  /// any nutrient values.
  CoachFoodSnapshot freezePersonal({
    required String ownerKey,
    required String ruleId,
    required int revision,
    required String inputUnit,
    required double gramsPerUnit,
  }) {
    final modern = snapshot;
    final source = CoachFoodSourceEvidence(
      kind: CoachFoodSourceKind.userFixed,
      ref: 'personal-bil:$ruleId',
      revision: 'r$revision',
      ownerKey: ownerKey,
      confidence: CoachFoodConfidence(
        score: 1,
        basis: 'Explicit user approval frozen at rule revision $revision',
      ),
    );
    if (modern != null) {
      return CoachFoodSnapshot(
        identity: 'personal:${modern.identity}',
        name: modern.name,
        preparedState: modern.preparedState,
        basisGrams: modern.basisGrams,
        nutrients: modern.nutrients,
        source: source,
      );
    }
    final rowUnit = normalizeFoodUnit(row.servingUnit);
    if (rowUnit != inputUnit || row.servingSize <= 0) {
      throw const CoachFoodContractError('fixed_rule_serving_mismatch');
    }
    return CoachFoodSnapshot(
      identity: 'personal:legacy-food:${row.uuid}',
      name: row.name,
      preparedState: 'as-recorded',
      basisGrams: row.servingSize * gramsPerUnit,
      nutrients: CoachFoodNutrients(evidence.values),
      source: source,
    );
  }
}

String normalizeFoodUnit(String value) {
  final unit = value.trim().toLowerCase();
  if (const {'g', 'gram', 'grams', 'غ', 'جرام', 'غرام'}.contains(unit)) {
    return 'g';
  }
  if (const {'ml', 'مل', 'ملي', 'milliliter', 'milliliters'}.contains(unit)) {
    return 'ml';
  }
  if (const {
    'item',
    'items',
    'piece',
    'pieces',
    'count',
    'egg',
    'eggs',
    'حبة',
    'حبه',
    'حبات',
    'بيضة',
    'بيضه',
    'بيضات',
    'scoop',
    'scoops',
    'سكوب',
    'serving',
    'servings',
    'حصة',
    'حصه',
  }.contains(unit)) {
    return 'item';
  }
  return unit;
}

String normalizeFoodConcept(String value) {
  var text = value.trim().toLowerCase();
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const eastern = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    text = text.replaceAll(arabic[i], '$i').replaceAll(eastern[i], '$i');
  }
  text = text
      .replaceAll(RegExp(r'[\u0640\u064b-\u065f\u0670]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
  return text.replaceAll(RegExp(r'\s+'), ' ');
}
