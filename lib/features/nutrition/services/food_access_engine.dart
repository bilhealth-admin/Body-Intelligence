import '../domain/food_access.dart';
import 'food_search_normalizer.dart';

class FoodAccessEngine {
  const FoodAccessEngine();

  List<FoodAccessCandidate> rank(
    Iterable<FoodAccessRecord> records, {
    String query = '',
    int limit = 20,
  }) {
    if (limit <= 0) return const <FoodAccessCandidate>[];

    final normalizedQuery = FoodSearchNormalizer.normalize(query);
    final candidates = <FoodAccessCandidate>[];
    for (final record in records) {
      final searchable = FoodSearchNormalizer.normalize(
        '${record.food.name} ${record.food.arabicName ?? ''} '
        '${record.food.category ?? ''} ${record.food.keywords.join(' ')}',
      );
      if (normalizedQuery.isNotEmpty && !searchable.contains(normalizedQuery)) {
        continue;
      }

      final reasons = <String>[];
      var score = 0.0;
      if (record.favorite) {
        score += 1000;
        reasons.add('favorite');
      }
      if (record.useCount > 0) {
        score += record.useCount.clamp(0, 100) * 10;
        reasons.add('frequency');
      }
      if (record.lastUsedAt != null) {
        score += 1;
        reasons.add('recency');
      }
      if (normalizedQuery.isNotEmpty) {
        score += 100;
        reasons.add('query-match');
      }

      candidates.add(
        FoodAccessCandidate(
          food: record.food,
          favorite: record.favorite,
          useCount: record.useCount,
          lastUsedAt: record.lastUsedAt,
          score: score,
          reasons: List<String>.unmodifiable(reasons),
        ),
      );
    }

    candidates.sort((left, right) {
      final favoriteOrder = (right.favorite ? 1 : 0).compareTo(
        left.favorite ? 1 : 0,
      );
      if (favoriteOrder != 0) return favoriteOrder;
      final frequencyOrder = right.useCount.compareTo(left.useCount);
      if (frequencyOrder != 0) return frequencyOrder;
      final leftDate =
          left.lastUsedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.lastUsedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final recencyOrder = rightDate.compareTo(leftDate);
      if (recencyOrder != 0) return recencyOrder;
      return left.food.name.toLowerCase().compareTo(
        right.food.name.toLowerCase(),
      );
    });

    return List<FoodAccessCandidate>.unmodifiable(candidates.take(limit));
  }
}
