import '../../../data/database/nutrient_evidence.dart';

enum FoodAnalysisCoverage { none, partial, complete }

class FoodAnalysisItemSnapshot {
  const FoodAnalysisItemSnapshot({
    required this.foodId,
    required this.foodName,
    required this.nutrientEvidenceMask,
    required this.values,
    required this.source,
    required this.verified,
  });

  final int foodId;
  final String foodName;
  final int nutrientEvidenceMask;
  final Map<TrackedNutrient, double> values;
  final String source;
  final bool verified;

  bool knows(TrackedNutrient nutrient) =>
      NutrientEvidenceMask.contains(nutrientEvidenceMask, nutrient);
}

class FoodNutrientContribution {
  const FoodNutrientContribution({
    required this.foodId,
    required this.foodName,
    required this.value,
    required this.share,
    required this.sources,
    required this.allSnapshotsVerified,
    required this.entryCount,
  });

  final int foodId;
  final String foodName;
  final double value;
  final double share;
  final Set<String> sources;
  final bool allSnapshotsVerified;
  final int entryCount;
}

class FoodNutrientAnalysis {
  const FoodNutrientAnalysis({
    required this.nutrient,
    required this.knownTotal,
    required this.knownEntryCount,
    required this.unknownEntryCount,
    required this.coverage,
    required this.contributors,
  });

  final TrackedNutrient nutrient;
  final double knownTotal;
  final int knownEntryCount;
  final int unknownEntryCount;
  final FoodAnalysisCoverage coverage;
  final List<FoodNutrientContribution> contributors;
}

/// Explains which logged foods contributed to a nutrient.
///
/// Only immutable meal-item snapshots carrying the nutrient's evidence bit
/// participate. Missing evidence remains unknown; it is never converted into
/// a zero. The engine describes contributions and deliberately makes no
/// "good" or "bad" food classification.
abstract final class FoodAnalysisEngine {
  static FoodNutrientAnalysis analyze({
    required Iterable<FoodAnalysisItemSnapshot> items,
    required TrackedNutrient nutrient,
    int limit = 5,
  }) {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final snapshots = items.toList(growable: false);
    final known = snapshots.where((item) => item.knows(nutrient)).toList();
    final unknownCount = snapshots.length - known.length;
    final groups = <int, _ContributionAccumulator>{};
    for (final item in known) {
      final value = item.values[nutrient];
      if (value == null || !value.isFinite || value < 0) continue;
      groups
          .putIfAbsent(
            item.foodId,
            () => _ContributionAccumulator(item.foodId, item.foodName),
          )
          .add(item, value);
    }
    final validKnownCount = groups.values.fold<int>(
      0,
      (sum, group) => sum + group.entryCount,
    );
    final invalidKnownCount = known.length - validKnownCount;
    final effectiveUnknownCount = unknownCount + invalidKnownCount;
    final total = groups.values.fold<double>(
      0,
      (sum, group) => sum + group.value,
    );
    final ranked = groups.values.toList()
      ..sort((a, b) {
        final valueOrder = b.value.compareTo(a.value);
        return valueOrder != 0
            ? valueOrder
            : a.foodName.toLowerCase().compareTo(b.foodName.toLowerCase());
      });
    final coverage = validKnownCount == 0
        ? FoodAnalysisCoverage.none
        : effectiveUnknownCount == 0
        ? FoodAnalysisCoverage.complete
        : FoodAnalysisCoverage.partial;
    return FoodNutrientAnalysis(
      nutrient: nutrient,
      knownTotal: total,
      knownEntryCount: validKnownCount,
      unknownEntryCount: effectiveUnknownCount,
      coverage: coverage,
      contributors: ranked
          .take(limit)
          .map((group) {
            return FoodNutrientContribution(
              foodId: group.foodId,
              foodName: group.foodName,
              value: group.value,
              share: total <= 0 ? 0 : group.value / total,
              sources: Set.unmodifiable(group.sources),
              allSnapshotsVerified: group.allSnapshotsVerified,
              entryCount: group.entryCount,
            );
          })
          .toList(growable: false),
    );
  }
}

class _ContributionAccumulator {
  _ContributionAccumulator(this.foodId, this.foodName);

  final int foodId;
  final String foodName;
  double value = 0;
  int entryCount = 0;
  bool allSnapshotsVerified = true;
  final Set<String> sources = {};

  void add(FoodAnalysisItemSnapshot item, double amount) {
    value += amount;
    entryCount += 1;
    allSnapshotsVerified = allSnapshotsVerified && item.verified;
    final source = item.source.trim();
    if (source.isNotEmpty) sources.add(source);
  }
}
