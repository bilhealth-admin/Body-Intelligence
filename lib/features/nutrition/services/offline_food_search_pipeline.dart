import '../domain/unified_food.dart';
import 'food_quality_engine.dart';
import 'food_search_normalizer.dart';

class FoodSearchHit {
  final UnifiedFood food;
  final double score;
  final List<String> reasons;

  const FoodSearchHit({
    required this.food,
    required this.score,
    required this.reasons,
  });
}

class OfflineFoodSearchPipeline {
  const OfflineFoodSearchPipeline();

  List<FoodSearchHit> search({
    required Iterable<UnifiedFood> foods,
    required String query,
    int limit = 50,
  }) {
    if (limit <= 0) return const <FoodSearchHit>[];

    final normalizedQuery = FoodSearchNormalizer.normalize(query);
    final queryTokens = FoodSearchNormalizer.tokens(query);
    final normalizedBarcode = FoodSearchNormalizer.normalizeBarcode(query);
    final hits = <FoodSearchHit>[];

    for (final food in foods) {
      final hit = _score(
        food,
        normalizedQuery: normalizedQuery,
        queryTokens: queryTokens,
        normalizedBarcode: normalizedBarcode,
      );
      if (normalizedQuery.isEmpty || hit.score > 0) hits.add(hit);
    }

    hits.sort((left, right) {
      final scoreOrder = right.score.compareTo(left.score);
      if (scoreOrder != 0) return scoreOrder;
      final qualityOrder = FoodQualityEngine.assess(
        right.food,
      ).score.compareTo(FoodQualityEngine.assess(left.food).score);
      if (qualityOrder != 0) return qualityOrder;
      return left.food.name.toLowerCase().compareTo(
        right.food.name.toLowerCase(),
      );
    });

    return List<FoodSearchHit>.unmodifiable(hits.take(limit));
  }

  FoodSearchHit _score(
    UnifiedFood food, {
    required String normalizedQuery,
    required List<String> queryTokens,
    required String normalizedBarcode,
  }) {
    final reasons = <String>[];
    var score = normalizedQuery.isEmpty ? 1.0 : 0.0;

    final name = FoodSearchNormalizer.normalize(food.name);
    final arabicName = FoodSearchNormalizer.normalize(food.arabicName ?? '');
    final category = FoodSearchNormalizer.normalize(food.category ?? '');
    final keywords = food.keywords
        .map(FoodSearchNormalizer.normalize)
        .where((value) => value.isNotEmpty)
        .join(' ');
    final searchable = '$name $arabicName $category $keywords'.trim();
    final barcode = FoodSearchNormalizer.normalizeBarcode(food.barcode ?? '');

    if (normalizedBarcode.isNotEmpty && barcode == normalizedBarcode) {
      score += 1000;
      reasons.add('barcode-exact');
    }
    if (normalizedQuery.isNotEmpty && name == normalizedQuery) {
      score += 500;
      reasons.add('primary-name-exact');
    }
    if (normalizedQuery.isNotEmpty && arabicName == normalizedQuery) {
      score += 500;
      reasons.add('arabic-name-exact');
    }
    if (normalizedQuery.isNotEmpty && name.startsWith(normalizedQuery)) {
      score += 250;
      reasons.add('primary-name-prefix');
    }
    if (normalizedQuery.isNotEmpty && arabicName.startsWith(normalizedQuery)) {
      score += 250;
      reasons.add('arabic-name-prefix');
    }
    if (normalizedQuery.isNotEmpty && searchable.contains(normalizedQuery)) {
      score += 120;
      reasons.add('phrase-match');
    }

    if (queryTokens.isNotEmpty) {
      final matched = queryTokens.where(searchable.contains).length;
      if (matched == queryTokens.length) {
        score += 80 + matched * 5;
        reasons.add('all-tokens-match');
      } else if (matched > 0) {
        score += matched * 12;
        reasons.add('partial-token-match');
      }
    }

    final hasMatch = reasons.isNotEmpty;
    if (hasMatch && food.verified) score += 5;
    if (hasMatch && food.source == FoodDataSource.foundation) score += 2;

    return FoodSearchHit(
      food: food,
      score: score,
      reasons: List<String>.unmodifiable(reasons),
    );
  }
}
