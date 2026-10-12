part of 'food_runtime_search_authority.dart';

extension _FoodRuntimeRanking on FoodRuntimeSearchAuthority {
  FoodSearchTextMatch _matchesSearchText({
    required String query,
    required String primaryName,
    String? arabicName,
    String? category,
    Iterable<String> keywords = const <String>[],
  }) {
    return FoodRuntimeSearchAuthority._textMatcher.match(
      query: query,
      queryVariants: FoodRuntimeSearchAuthority._searchAssistance.expand(query),
      primaryName: primaryName,
      arabicName: arabicName,
      category: category,
      keywords: keywords,
    );
  }

  FoodSearchTextMatch _matchQuery(UnifiedFood food, String query) =>
      _matchesSearchText(
        query: query,
        primaryName: food.name,
        arabicName: food.arabicName,
        category: food.category,
        keywords: food.keywords,
      );

  FoodSearchTextMatch _matchLocalFood(Food food, String query) =>
      _matchesSearchText(
        query: query,
        primaryName: food.name,
        arabicName: food.arabicName,
        category: food.category,
        keywords: food.keywords.split(','),
      );

  List<UnifiedFood> _rankUnifiedFoods(
    Iterable<UnifiedFood> foods,
    String query,
  ) {
    final matched = foods
        .map((food) => (food: food, match: _matchQuery(food, query)))
        .where((entry) => entry.match.matches)
        .toList(growable: false);
    final ranked =
        FoodRuntimeSearchAuthority._textMatcher.suppressIncompleteTokenPrefixes(
          matched,
          (entry) => entry.match,
        )..sort((left, right) => right.match.rank.compareTo(left.match.rank));
    return ranked.map((entry) => entry.food).toList(growable: false);
  }

  List<Food> _rankLocalFoods(Iterable<Food> foods, String query) {
    final matched = foods
        .map((food) => (food: food, match: _matchLocalFood(food, query)))
        .where((entry) => entry.match.matches)
        .toList(growable: false);
    final ranked =
        FoodRuntimeSearchAuthority._textMatcher.suppressIncompleteTokenPrefixes(
          matched,
          (entry) => entry.match,
        )..sort((left, right) => right.match.rank.compareTo(left.match.rank));
    return ranked.map((entry) => entry.food).toList(growable: false);
  }
}
