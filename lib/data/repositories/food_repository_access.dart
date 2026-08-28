part of 'food_repository.dart';

/// Food discovery access and favorite state are kept together because they
/// share the same local ranking inputs and must remain transactionally local.
mixin _FoodRepositoryAccessMethods {
  AppDatabase get _database;
  UnifiedFoodAdapter get _adapter;
  FoodAccessEngine get _foodAccessEngine;
  Future<List<Food>> getFoods();

  Future<List<FoodAccessCandidate>> foodAccessCandidates({
    String query = '',
    int limit = 20,
  }) async {
    if (limit <= 0) return const <FoodAccessCandidate>[];
    final foods = await getFoods();
    final favoriteRows = await _database.select(_database.favorites).get();
    final recentRows = await _database.select(_database.recentFoods).get();
    final favoriteIds = favoriteRows.map((row) => row.foodId).toSet();
    final recentsByFoodId = {for (final row in recentRows) row.foodId: row};
    return _foodAccessEngine.rank(
      foods.map((food) {
        final recent = recentsByFoodId[food.id];
        return FoodAccessRecord(
          food: _adapter.adapt(food),
          favorite: favoriteIds.contains(food.id),
          useCount: recent?.useCount ?? 0,
          lastUsedAt: recent?.lastUsedAt,
        );
      }),
      query: query,
      limit: limit,
    );
  }

  Future<void> setFavorite(int foodId, bool favorite) async {
    if (favorite) {
      await _database
          .into(_database.favorites)
          .insert(
            FavoritesCompanion.insert(foodId: foodId),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_database.delete(
        _database.favorites,
      )..where((row) => row.foodId.equals(foodId))).go();
    }
  }

  Future<bool> isFavorite(int foodId) async {
    final row = await (_database.select(
      _database.favorites,
    )..where((favorite) => favorite.foodId.equals(foodId))).getSingleOrNull();
    return row != null;
  }
}
