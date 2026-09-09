part of 'food_repository.dart';

extension _FoodRepositoryRanking on FoodRepository {
  /// Uses SQLite to cheaply narrow ordinary ASCII searches before adapting
  /// and ranking rows in Dart. The full in-memory path remains the fallback
  /// for non-ASCII normalization and for queries without a literal candidate,
  /// preserving the multilingual/fuzzy search contract.
  Future<List<Food>> _searchCandidates(
    String query, {
    bool customOnly = false,
  }) async {
    final tokens = FoodSearchNormalizer.tokens(query);
    if (tokens.isEmpty ||
        tokens.any((token) => !RegExp(r'^[a-z0-9]+$').hasMatch(token))) {
      final all = await getFoods();
      return customOnly
          ? all.where((food) => food.isCustom).toList(growable: false)
          : all;
    }

    final statement = _database.select(_database.foods)
      ..where((row) {
        Expression<bool> matchesToken(String token) {
          final pattern = '%$token%';
          return row.name.like(pattern) |
              row.arabicName.like(pattern) |
              row.category.like(pattern) |
              row.keywords.like(pattern) |
              row.barcode.like(pattern);
        }

        var predicate = row.deletedAt.isNull();
        if (customOnly) predicate = predicate & row.isCustom.equals(true);
        for (final token in tokens) {
          predicate = predicate & matchesToken(token);
        }
        return predicate;
      });
    final candidates = await statement.get();
    if (candidates.isNotEmpty) return candidates;

    final all = await getFoods();
    return customOnly
        ? all.where((food) => food.isCustom).toList(growable: false)
        : all;
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
