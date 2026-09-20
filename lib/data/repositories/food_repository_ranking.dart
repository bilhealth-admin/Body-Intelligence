part of 'food_repository.dart';

extension FoodRepositoryRanking on FoodRepository {
  /// Returns the explicitly popular foods for the standalone Food Log.
  ///
  /// A food becomes popular only after more than three confirmed selections
  /// (the default threshold is four). This method is intentionally separate
  /// from [search] so the existing Daily Log search/ranking contract remains
  /// unchanged.
  Future<List<Food>> popularFoods({
    int minimumUseCount = 4,
    int limit = 30,
  }) async {
    if (limit <= 0) return const <Food>[];
    final foods = await getFoods();
    if (foods.isEmpty) return const <Food>[];

    final threshold = minimumUseCount < 1 ? 1 : minimumUseCount;
    final recentRows = await _database.select(_database.recentFoods).get();
    final recentsByFoodId = {for (final row in recentRows) row.foodId: row};
    final popular = foods
        .where((food) => (recentsByFoodId[food.id]?.useCount ?? 0) >= threshold)
        .toList();
    popular.sort((left, right) {
      final rightRecent = recentsByFoodId[right.id];
      final leftRecent = recentsByFoodId[left.id];
      final useCountOrder = (rightRecent?.useCount ?? 0).compareTo(
        leftRecent?.useCount ?? 0,
      );
      if (useCountOrder != 0) return useCountOrder;
      final lastUsedOrder =
          (rightRecent?.lastUsedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                leftRecent?.lastUsedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0),
              );
      if (lastUsedOrder != 0) return lastUsedOrder;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return List<Food>.unmodifiable(popular.take(limit));
  }

  Future<List<Food>> _rankPersonalizedFoods(
    List<Food> foods, {
    required int limit,
  }) async {
    if (limit <= 0 || foods.isEmpty) return const <Food>[];

    final favoriteRows = await _database.select(_database.favorites).get();
    final recentRows = await _database.select(_database.recentFoods).get();
    final favoriteIds = favoriteRows.map((row) => row.foodId).toSet();
    final recentsByFoodId = {for (final row in recentRows) row.foodId: row};

    final ranked = List<Food>.of(foods);
    ranked.sort((left, right) {
      final favoriteOrder = (favoriteIds.contains(right.id) ? 1 : 0).compareTo(
        favoriteIds.contains(left.id) ? 1 : 0,
      );
      if (favoriteOrder != 0) return favoriteOrder;

      final leftRecent = recentsByFoodId[left.id];
      final rightRecent = recentsByFoodId[right.id];
      final useCountOrder = (rightRecent?.useCount ?? 0).compareTo(
        leftRecent?.useCount ?? 0,
      );
      if (useCountOrder != 0) return useCountOrder;

      final lastUsedOrder =
          (rightRecent?.lastUsedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                leftRecent?.lastUsedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0),
              );
      if (lastUsedOrder != 0) return lastUsedOrder;

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return List<Food>.unmodifiable(ranked.take(limit));
  }
}
