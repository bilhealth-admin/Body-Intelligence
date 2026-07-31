import '../domain/unified_food.dart';
import 'food_search_normalizer.dart';
import 'food_unit_engine.dart';

enum FoodMigrationIssueKind {
  blankStableId,
  blankPrimaryName,
  nonCanonicalPrimaryName,
  unknownSource,
  nonCanonicalSourceLabel,
  invalidServingBasis,
  unsupportedServingUnit,
  nonCanonicalServingUnit,
  nonCanonicalBarcode,
  duplicateKeyword,
  blankKeyword,
  customSourceMismatch,
}

class FoodMigrationIssue {
  final FoodMigrationIssueKind kind;
  final String message;

  const FoodMigrationIssue({required this.kind, required this.message});
}

class FoodMigrationPlan {
  final UnifiedFood original;
  final UnifiedFood canonical;
  final List<FoodMigrationIssue> issues;

  const FoodMigrationPlan({
    required this.original,
    required this.canonical,
    required this.issues,
  });

  bool get requiresPersistence => issues.isNotEmpty;

  /// Migration discovery is intentionally read-only in EPIC 004.
  bool get shouldAutoPersist => false;
}

class FoodMigrationEngine {
  const FoodMigrationEngine._();

  static List<FoodMigrationPlan> auditAll(
    Iterable<UnifiedFood> foods, {
    int limit = 1000,
  }) {
    if (limit <= 0) return const <FoodMigrationPlan>[];

    final plans =
        foods
            .map(audit)
            .where((plan) => plan.requiresPersistence)
            .toList(growable: false)
          ..sort((left, right) {
            final issueOrder = right.issues.length.compareTo(
              left.issues.length,
            );
            if (issueOrder != 0) return issueOrder;
            return left.original.name.toLowerCase().compareTo(
              right.original.name.toLowerCase(),
            );
          });

    return List<FoodMigrationPlan>.unmodifiable(plans.take(limit));
  }

  static FoodMigrationPlan audit(UnifiedFood food) {
    final issues = <FoodMigrationIssue>[];

    final id = food.id.trim();
    if (id.isEmpty) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.blankStableId,
          message: 'A stable food id is required before persistence.',
        ),
      );
    }

    final name = food.name.trim();
    if (name.isEmpty) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.blankPrimaryName,
          message: 'A primary food name is required.',
        ),
      );
    } else if (food.name != name) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.nonCanonicalPrimaryName,
          message: 'Primary food name contains non-canonical whitespace.',
        ),
      );
    }

    if (food.source == FoodDataSource.unknown) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.unknownSource,
          message: 'The source cannot be migrated without source evidence.',
        ),
      );
    }

    if (food.isCustom && food.source != FoodDataSource.custom) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.customSourceMismatch,
          message: 'Custom foods must use the custom source classification.',
        ),
      );
    }

    final canonicalSourceLabel = _canonicalSourceLabel(food.source);
    if (food.sourceLabel.trim().toLowerCase() != canonicalSourceLabel) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.nonCanonicalSourceLabel,
          message: 'Source label is not canonical.',
        ),
      );
    }

    final serving = _canonicalServing(food.serving, issues);
    final barcode = _canonicalBarcode(food.barcode, issues);
    final keywords = _canonicalKeywords(food.keywords, issues);

    final canonical = UnifiedFood(
      id: id,
      localId: food.localId,
      name: name,
      arabicName: _nullableTrim(food.arabicName),
      category: _nullableTrim(food.category),
      keywords: keywords,
      barcode: barcode,
      serving: serving,
      nutrients: Map<FoodNutrient, NutrientAmount>.unmodifiable(food.nutrients),
      source: food.isCustom ? FoodDataSource.custom : food.source,
      sourceLabel: food.isCustom ? 'custom' : canonicalSourceLabel,
      verified: food.verified,
      isCustom: food.isCustom,
      updatedAt: food.updatedAt,
    );

    return FoodMigrationPlan(
      original: food,
      canonical: canonical,
      issues: List<FoodMigrationIssue>.unmodifiable(issues),
    );
  }

  static FoodServing _canonicalServing(
    FoodServing serving,
    List<FoodMigrationIssue> issues,
  ) {
    final amount = serving.amount;
    final grams = serving.grams;
    if (!amount.isFinite || amount <= 0 || !grams.isFinite || grams <= 0) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.invalidServingBasis,
          message: 'Serving amount and gram basis must be finite and positive.',
        ),
      );
      return serving;
    }

    final parsed = FoodUnitEngine.tryParse(serving.unit);
    if (parsed == null) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.unsupportedServingUnit,
          message: 'Serving unit is not a supported mass unit.',
        ),
      );
      return FoodServing(
        amount: amount,
        unit: serving.unit.trim(),
        grams: grams,
      );
    }

    final canonicalUnit = switch (parsed) {
      FoodMassUnit.gram => 'g',
      FoodMassUnit.kilogram => 'kg',
      FoodMassUnit.ounce => 'oz',
      FoodMassUnit.pound => 'lb',
    };
    if (serving.unit.trim().toLowerCase() != canonicalUnit) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.nonCanonicalServingUnit,
          message: 'Serving unit should use its canonical symbol.',
        ),
      );
    }

    return FoodServing(amount: amount, unit: canonicalUnit, grams: grams);
  }

  static String? _canonicalBarcode(
    String? value,
    List<FoodMigrationIssue> issues,
  ) {
    final trimmed = _nullableTrim(value);
    if (trimmed == null) return null;

    final normalized = FoodSearchNormalizer.normalizeBarcode(trimmed);
    if (normalized != trimmed) {
      issues.add(
        const FoodMigrationIssue(
          kind: FoodMigrationIssueKind.nonCanonicalBarcode,
          message: 'Barcode contains non-canonical separators or digits.',
        ),
      );
    }
    return normalized.isEmpty ? null : normalized;
  }

  static List<String> _canonicalKeywords(
    List<String> values,
    List<FoodMigrationIssue> issues,
  ) {
    final seen = <String>{};
    final canonical = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        issues.add(
          const FoodMigrationIssue(
            kind: FoodMigrationIssueKind.blankKeyword,
            message: 'Blank keywords are removed.',
          ),
        );
        continue;
      }

      final identity = FoodSearchNormalizer.normalize(trimmed);
      if (!seen.add(identity)) {
        issues.add(
          const FoodMigrationIssue(
            kind: FoodMigrationIssueKind.duplicateKeyword,
            message: 'Duplicate normalized keywords are removed.',
          ),
        );
        continue;
      }
      canonical.add(trimmed);
    }
    return List<String>.unmodifiable(canonical);
  }

  static String _canonicalSourceLabel(FoodDataSource source) =>
      switch (source) {
        FoodDataSource.foundation => 'foundation',
        FoodDataSource.legacy => 'legacy',
        FoodDataSource.branded => 'branded',
        FoodDataSource.custom => 'custom',
        FoodDataSource.unknown => 'unknown',
      };

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
