part of 'food_repository.dart';

extension _FoodRepositoryRanking on FoodRepository {
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
