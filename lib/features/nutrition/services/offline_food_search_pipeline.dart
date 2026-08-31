import '../domain/unified_food.dart';
import 'food_quality_engine.dart';
import 'food_search_normalizer.dart';
import 'food_search_text_matcher.dart';

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

  static const FoodSearchTextMatcher _textMatcher = FoodSearchTextMatcher();

  List<FoodSearchHit> search({
    required Iterable<UnifiedFood> foods,
    required String query,
    int limit = 50,
  }) {
    if (limit <= 0) return const <FoodSearchHit>[];

    final normalizedQuery = FoodSearchNormalizer.normalize(query);
    final queryTokens = FoodSearchNormalizer.tokens(query);
    final normalizedBarcode = FoodSearchNormalizer.normalizeBarcode(query);
    final scoredHits = <({FoodSearchHit hit, FoodSearchTextMatch textMatch})>[];

    for (final food in foods) {
      final scored = _score(
        food,
        normalizedQuery: normalizedQuery,
        queryTokens: queryTokens,
        normalizedBarcode: normalizedBarcode,
      );
      if (normalizedQuery.isEmpty || scored.hit.score > 0) {
        scoredHits.add(scored);
      }
    }

    final hits = _textMatcher.suppressIncompleteTokenPrefixes(
      scoredHits,
      (entry) => entry.textMatch,
    );
    hits.sort((left, right) {
      final scoreOrder = right.hit.score.compareTo(left.hit.score);
      if (scoreOrder != 0) return scoreOrder;
      final qualityOrder = FoodQualityEngine.assess(
        right.hit.food,
      ).score.compareTo(FoodQualityEngine.assess(left.hit.food).score);
      if (qualityOrder != 0) return qualityOrder;
      return left.hit.food.name.toLowerCase().compareTo(
        right.hit.food.name.toLowerCase(),
      );
    });

    return List<FoodSearchHit>.unmodifiable(
      hits.take(limit).map((entry) => entry.hit),
    );
  }

  ({FoodSearchHit hit, FoodSearchTextMatch textMatch}) _score(
    UnifiedFood food, {
    required String normalizedQuery,
    required List<String> queryTokens,
    required String normalizedBarcode,
  }) {
    final reasons = <String>[];
    var score = normalizedQuery.isEmpty ? 1.0 : 0.0;
    var textMatch = const FoodSearchTextMatch();

    final barcode = FoodSearchNormalizer.normalizeBarcode(food.barcode ?? '');

    if (normalizedBarcode.isNotEmpty && barcode == normalizedBarcode) {
      score += 1000;
      reasons.add('barcode-exact');
    }
    if (normalizedQuery.isNotEmpty && queryTokens.isNotEmpty) {
      textMatch = _textMatcher.match(
        query: normalizedQuery,
        primaryName: food.name,
        arabicName: food.arabicName,
        category: food.category,
        keywords: food.keywords,
      );
      if (textMatch.matches) {
        score += switch (textMatch.tier) {
          FoodSearchTextMatchTier.exact => 500,
          FoodSearchTextMatchTier.primaryPhrasePrefix => 350,
          FoodSearchTextMatchTier.wordPrefix => 250,
          FoodSearchTextMatchTier.keywordOrContains => 150,
          FoodSearchTextMatchTier.none => 0,
        };
        reasons.add(_textReason(textMatch));
      }
    }

    final hasMatch = reasons.isNotEmpty;
    if (hasMatch && food.verified) score += 5;
    if (hasMatch && food.source == FoodDataSource.foundation) score += 2;

    return (
      hit: FoodSearchHit(
        food: food,
        score: score,
        reasons: List<String>.unmodifiable(reasons),
      ),
      textMatch: textMatch,
    );
  }

  String _textReason(FoodSearchTextMatch match) {
    final field = switch (match.field) {
      FoodSearchTextField.primaryName => 'primary-name',
      FoodSearchTextField.arabicName => 'arabic-name',
      FoodSearchTextField.category => 'category',
      FoodSearchTextField.keyword => 'keyword',
      null => 'text',
    };
    final tier = switch (match.tier) {
      FoodSearchTextMatchTier.exact => 'exact',
      FoodSearchTextMatchTier.primaryPhrasePrefix => 'phrase-prefix',
      FoodSearchTextMatchTier.wordPrefix => 'word-prefix',
      FoodSearchTextMatchTier.keywordOrContains => 'contains',
      FoodSearchTextMatchTier.none => 'none',
    };
    return '$field-$tier';
  }
}
