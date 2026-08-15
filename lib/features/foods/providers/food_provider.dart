import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/database/seed_data.dart';
import '../../../data/repositories/food_repository.dart';
import '../../../data/repositories/meal_repository.dart';
import '../../nutrition/repositories/unified_food_repository.dart';
import '../../nutrition/services/active_mobile_catalog_resolver.dart';
import '../../nutrition/services/food_runtime_search_authority.dart';

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return FoodRepository(database);
});

final unifiedFoodRepositoryProvider = Provider<UnifiedFoodRepository>((ref) {
  return ref.watch(foodRepositoryProvider);
});

final activeMobileCatalogResolverProvider =
    Provider<ActiveMobileCatalogResolver>((ref) {
      return ActiveMobileCatalogResolver();
    });

final foodRuntimeSearchAuthorityProvider = Provider<FoodRuntimeSearchAuthority>(
  (ref) {
    final catalogResolver = ref.watch(activeMobileCatalogResolverProvider);
    return FoodRuntimeSearchAuthority(
      ref.watch(foodRepositoryProvider),
      catalogResolver: catalogResolver.openIfAvailable,
    );
  },
);

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return MealRepository(database);
});

final foodsProvider = StreamProvider<List<Food>>((ref) {
  // Seeding is intentionally lazy: startup/profile restoration must never wait
  // for catalog maintenance. Inserts automatically update this stream.
  ref.watch(seedCatalogProvider);
  final repository = ref.watch(foodRepositoryProvider);
  return repository.watchFoods();
});

final favoriteFoodsProvider = StreamProvider<List<Food>>((ref) {
  return ref.watch(foodRepositoryProvider).watchFavorites();
});

final recentFoodsProvider = StreamProvider<List<Food>>((ref) {
  return ref.watch(foodRepositoryProvider).watchRecent();
});

final seedCatalogProvider = FutureProvider<void>((ref) {
  return SeedData.seedStarterCatalog(ref.watch(foodRepositoryProvider));
});
