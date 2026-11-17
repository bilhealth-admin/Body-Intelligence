part of 'coach_media_catalog_entry.dart';

/// Read-only candidates from the same installed catalog used by Food Log.
///
/// These are search candidates, never an inferred exact food identity. The
/// existing media bridge still requires explicit selection and portion review.
/// No local food row, meal, catalog evidence, or guessed grams are written here.
final class CoachMediaInstalledCatalogLookup {
  const CoachMediaInstalledCatalogLookup({
    required this.openCatalog,
    required this.ownerKey,
    this.isCurrent,
  });

  final Future<UnifiedFoodRepository?> Function() openCatalog;
  final String ownerKey;
  final bool Function()? isCurrent;

  bool _current(CoachMediaAttempt attempt) {
    try {
      if (attempt.ownerScope.captured.ownerKey == ownerKey &&
          (isCurrent?.call() ?? true) &&
          attempt.canAcceptResult) {
        return true;
      }
    } on Object {
      // A disposed provider cannot authorize a result from its old visit.
    }
    attempt.cancel();
    return false;
  }

  Future<List<CoachMediaCatalogEntry>> lookup(
    String query,
    CoachMediaAttempt attempt,
  ) async {
    if (!_current(attempt) ||
        query.trim().isEmpty ||
        query.runes.length > 200 ||
        query.runes.any((rune) => rune < 32 || rune == 127)) {
      return const [];
    }
    final catalog = await openCatalog();
    try {
      if (!_current(attempt) ||
          // Do not accept owner-local or optional network repositories here.
          !(catalog is UsdaCoreCatalogRepository ||
              catalog is MobileCatalogFoodRepository ||
              catalog is CompositeFoodCatalogRepository)) {
        return const [];
      }
      final hits = await catalog!.searchUnified(query, limit: 12);
      if (!_current(attempt)) return const [];
      final entries = <CoachMediaCatalogEntry>[];
      for (final hit in hits.take(12)) {
        if (!_current(attempt)) return const [];
        final expected = _snapshot(hit.food);
        if (expected == null) continue;
        // Bind the candidate to the actual installed repository, rather than
        // accepting an arbitrary UnifiedFood or a legacy source-label string.
        final actual = await catalog.findById(hit.food.id);
        if (!_current(attempt)) return const [];
        if (actual == null) continue;
        final snapshot = _snapshot(actual);
        if (snapshot == null || snapshot.digest != expected.digest) continue;
        entries.add(
          CoachMediaCatalogEntry._(
            row: _presentation(actual, snapshot),
            food: snapshot,
            unitRule: null,
          ),
        );
      }
      return List.unmodifiable(entries);
    } finally {
      if (catalog is CompositeFoodCatalogRepository) {
        catalog.close();
      } else if (catalog is MobileCatalogFoodRepository) {
        catalog.close();
      } else if (catalog is UsdaCoreCatalogRepository) {
        catalog.close();
      }
    }
  }

  static CoachFoodSnapshot? _snapshot(UnifiedFood food) {
    if (food.localId != null ||
        food.isCustom ||
        !food.verified ||
        (food.source != FoodDataSource.foundation &&
            food.source != FoodDataSource.legacy) ||
        !CoachMediaCatalogEntry._boundedText(food.id, 128) ||
        !CoachMediaCatalogEntry._boundedText(food.name, 240) ||
        !CoachMediaCatalogEntry._boundedText(food.sourceLabel, 200) ||
        food.id != food.id.trim() ||
        !food.serving.grams.isFinite ||
        food.serving.grams < .001 ||
        food.serving.grams > 100000 ||
        !const [
          FoodNutrient.calories,
          FoodNutrient.protein,
          FoodNutrient.carbohydrates,
          FoodNutrient.fat,
        ].every((nutrient) => food.knownValue(nutrient) != null)) {
      return null;
    }
    try {
      final nutrients = CoachFoodNutrients({
        for (final nutrient in FoodNutrient.values)
          nutrient: food.knownValue(nutrient),
      });
      final content = jsonEncode({
        'id': food.id,
        'name': food.name,
        'source': food.source.name,
        'sourceLabel': food.sourceLabel,
        'basisGrams': food.serving.grams,
        'publishedAt': food.updatedAt?.toUtc().toIso8601String(),
        'nutrients': nutrients.toJson(),
      });
      return CoachFoodSnapshot(
        identity: food.id,
        name: food.name,
        preparedState: 'as-listed-in-installed-catalog',
        basisGrams: food.serving.grams,
        nutrients: nutrients,
        source: CoachFoodSourceEvidence(
          kind: CoachFoodSourceKind.reference,
          ref: food.sourceLabel,
          revision: 'catalog:${sha256.convert(utf8.encode(content))}',
        ),
      );
    } on CoachFoodContractError {
      return null;
    } on JsonUnsupportedObjectError {
      return null;
    }
  }

  /// Adapter for the existing selection widget only. id=0 explicitly denotes
  /// an unpersisted presentation row. It never enters a repository/FK write;
  /// the existing Coach journal receives [snapshot] after final confirmation.
  static Food _presentation(UnifiedFood food, CoachFoodSnapshot snapshot) {
    double value(FoodNutrient nutrient) => snapshot.nutrients[nutrient] ?? 0;
    final at =
        food.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final row = Food(
      id: 0,
      uuid: food.id,
      name: food.name,
      arabicName: food.arabicName,
      category: food.category ?? 'catalog',
      keywords: food.keywords.join(','),
      barcode: food.barcode,
      servingSize: snapshot.basisGrams,
      servingUnit: 'g',
      calories: value(FoodNutrient.calories),
      protein: value(FoodNutrient.protein),
      carbs: value(FoodNutrient.carbohydrates),
      fats: value(FoodNutrient.fat),
      fiber: value(FoodNutrient.fiber),
      sugar: value(FoodNutrient.sugar),
      sodium: value(FoodNutrient.sodium),
      potassium: value(FoodNutrient.potassium),
      calcium: value(FoodNutrient.calcium),
      magnesium: value(FoodNutrient.magnesium),
      phosphorus: value(FoodNutrient.phosphorus),
      iron: value(FoodNutrient.iron),
      vitaminC: value(FoodNutrient.vitaminC),
      nutrientEvidenceMask: NutrientEvidenceMask.fromValues(
        calories: snapshot.nutrients[FoodNutrient.calories],
        protein: snapshot.nutrients[FoodNutrient.protein],
        carbohydrates: snapshot.nutrients[FoodNutrient.carbohydrates],
        fat: snapshot.nutrients[FoodNutrient.fat],
        fiber: snapshot.nutrients[FoodNutrient.fiber],
        sugar: snapshot.nutrients[FoodNutrient.sugar],
        sodium: snapshot.nutrients[FoodNutrient.sodium],
        potassium: snapshot.nutrients[FoodNutrient.potassium],
        calcium: snapshot.nutrients[FoodNutrient.calcium],
        magnesium: snapshot.nutrients[FoodNutrient.magnesium],
        phosphorus: snapshot.nutrients[FoodNutrient.phosphorus],
      ),
      source: food.sourceLabel,
      verified: true,
      isCustom: false,
      createdAt: at,
      updatedAt: at,
      revision: 1,
      syncStatus: 'presentation-only',
    );
    // Nullable catalog evidence keeps a missing nutrient distinct from zero
    // in this projection, exactly as in the selected immutable snapshot.
    return row.copyWith(
      foodEvidenceJson: Value(
        FoodBasisEvidence.encodeCatalog(row, snapshot.nutrients.values),
      ),
    );
  }
}
