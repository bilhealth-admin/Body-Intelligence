part of 'food_repository.dart';

mixin _FoodRepositoryReadStreams {
  AppDatabase get _database;

  Stream<List<Food>> watchFavorites() async* {
    final query =
        _database.select(_database.foods).join([
            innerJoin(
              _database.favorites,
              _database.favorites.foodId.equalsExp(_database.foods.id),
            ),
          ])
          ..where(_database.foods.deletedAt.isNull())
          ..orderBy([OrderingTerm.asc(_database.foods.name)]);
    List<Food> decode(List<TypedResult> rows) =>
        rows.map((row) => row.readTable(_database.foods)).toList();
    yield decode(await query.get());
    yield* query.watch().map(decode).skip(1);
  }

  Stream<List<Food>> watchRecent({int limit = 20}) async* {
    final query =
        _database.select(_database.foods).join([
            innerJoin(
              _database.recentFoods,
              _database.recentFoods.foodId.equalsExp(_database.foods.id),
            ),
          ])
          ..where(_database.foods.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(_database.recentFoods.lastUsedAt)])
          ..limit(limit);
    List<Food> decode(List<TypedResult> rows) =>
        rows.map((row) => row.readTable(_database.foods)).toList();
    yield decode(await query.get());
    yield* query.watch().map(decode).skip(1);
  }
}
