import '../../../data/database/app_database.dart';
import '../../../data/repositories/food_repository.dart';
import '../repositories/mobile_catalog_food_repository.dart';
import '../repositories/composite_food_catalog_repository.dart';
import '../repositories/usda_core_catalog_repository.dart';
import '../repositories/unified_food_repository.dart';
import '../domain/product_identity.dart';
import '../domain/unified_food.dart';
import '../domain/barcode_identity.dart';
import 'active_mobile_catalog_resolver.dart';
import 'barcode_food_contract.dart';
import 'food_search_normalizer.dart';
import 'food_search_assistance.dart';
import 'regional_barcode_network_resolver.dart';

typedef MobileCatalogRepositoryResolver =
    Future<UnifiedFoodRepository?> Function();
typedef CommunityFoodSearchResolver =
    Future<List<UnifiedFood>> Function(String query, {int limit});

enum FoodRuntimeSearchSource { localOnly, catalogAndLocal, localFallback }

enum FoodRuntimeBarcodeStatus {
  invalid,
  found,
  identifiedProduct,
  notFound,
  degraded,
}

class FoodRuntimeBarcodeResult {
  final FoodRuntimeBarcodeStatus status;
  final List<Food> foods;
  final FoodRuntimeSearchSource source;
  final String normalizedBarcode;
  final ProductIdentity? product;

  const FoodRuntimeBarcodeResult({
    required this.status,
    required this.foods,
    required this.source,
    required this.normalizedBarcode,
    this.product,
  });

  bool get found => status == FoodRuntimeBarcodeStatus.found;
  bool get invalid => status == FoodRuntimeBarcodeStatus.invalid;
  bool get degraded => status == FoodRuntimeBarcodeStatus.degraded;
}

class FoodRuntimeSearchResult {
  final List<Food> foods;
  final FoodRuntimeSearchSource source;

  const FoodRuntimeSearchResult({required this.foods, required this.source});

  bool get catalogUsed => source == FoodRuntimeSearchSource.catalogAndLocal;

  bool get degraded => source == FoodRuntimeSearchSource.localFallback;
}

class FoodRuntimeSearchAuthority {
  static const FoodSearchAssistance _searchAssistance = FoodSearchAssistance();
  final FoodRepository _localRepository;
  final MobileCatalogRepositoryResolver _catalogResolver;
  final CommunityFoodSearchResolver? communitySearchResolver;
  final RegionalBarcodeNetworkResolver _networkBarcodeResolver;

  FoodRuntimeSearchAuthority(
    this._localRepository, {
    MobileCatalogRepositoryResolver? catalogResolver,
    this.communitySearchResolver,
    this._networkBarcodeResolver = const RegionalBarcodeNetworkResolver(),
  }) : _catalogResolver =
           catalogResolver ?? ActiveMobileCatalogResolver().openIfAvailable;

  Future<List<Food>> search(String query, {int limit = 50}) async {
    return (await searchDetailed(query, limit: limit)).foods;
  }

  Future<Food?> findExact(String id) async {
    final local = await _localRepository.findById(id);
    if (local != null) return _localRepository.materializeUnifiedFood(local);
    UnifiedFoodRepository? catalog;
    try {
      catalog = await _catalogResolver();
      final unified = await catalog?.findById(id);
      return unified == null
          ? null
          : await _localRepository.materializeUnifiedFood(unified);
    } catch (_) {
      return null;
    } finally {
      if (catalog is CompositeFoodCatalogRepository) {
        catalog.close();
      } else if (catalog is MobileCatalogFoodRepository) {
        catalog.close();
      } else if (catalog is UsdaCoreCatalogRepository) {
        catalog.close();
      }
    }
  }

  Future<FoodRuntimeSearchResult> searchDetailed(
    String query, {
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) {
      return FoodRuntimeSearchResult(
        foods: await _localRepository.search(query, limit: limit),
        source: FoodRuntimeSearchSource.localOnly,
      );
    }

    final local = await _searchLocal(query, limit: limit);
    final community = await _loadCommunity(query, limit: limit);

    UnifiedFoodRepository? catalog;
    try {
      catalog = await _catalogResolver();
    } catch (_) {
      return FoodRuntimeSearchResult(
        foods: _mergeCommunity(local, const <Food>[], community, limit: limit),
        source: community.isEmpty
            ? FoodRuntimeSearchSource.localFallback
            : FoodRuntimeSearchSource.catalogAndLocal,
      );
    }

    if (catalog == null) {
      return FoodRuntimeSearchResult(
        foods: _mergeCommunity(local, const <Food>[], community, limit: limit),
        source: community.isEmpty
            ? FoodRuntimeSearchSource.localOnly
            : FoodRuntimeSearchSource.catalogAndLocal,
      );
    }

    try {
      final expandedLimit = (limit * 5).clamp(limit, 250);
      final hits = await catalog.searchUnified(query, limit: expandedLimit);
      final materialized = <Food>[];
      for (final hit in hits.where((hit) => _matchesQuery(hit.food, query))) {
        materialized.add(
          await _localRepository.materializeUnifiedFood(hit.food),
        );
        if (materialized.length >= limit) break;
      }
      return FoodRuntimeSearchResult(
        foods: _mergeCommunity(materialized, local, community, limit: limit),
        source: FoodRuntimeSearchSource.catalogAndLocal,
      );
    } catch (_) {
      return FoodRuntimeSearchResult(
        foods: _mergeCommunity(local, const <Food>[], community, limit: limit),
        source: community.isEmpty
            ? FoodRuntimeSearchSource.localFallback
            : FoodRuntimeSearchSource.catalogAndLocal,
      );
    } finally {
      if (catalog is CompositeFoodCatalogRepository) {
        catalog.close();
      } else if (catalog is MobileCatalogFoodRepository) {
        catalog.close();
      } else if (catalog is UsdaCoreCatalogRepository) {
        catalog.close();
      }
    }
  }

  Future<List<Food>> _loadCommunity(String query, {required int limit}) async {
    final resolver = communitySearchResolver;
    if (resolver == null || limit <= 0) return const <Food>[];
    try {
      final unified = await resolver(query, limit: limit < 10 ? limit : 10);
      final foods = <Food>[];
      // The server is an acceleration source, not the search authority. A
      // stale RPC/cache must never inject unrelated foods into a typed query.
      for (final food in unified.where((food) => _matchesQuery(food, query))) {
        foods.add(await _localRepository.materializeUnifiedFood(food));
      }
      return foods;
    } catch (_) {
      return const <Food>[];
    }
  }

  Future<List<Food>> _searchLocal(String query, {required int limit}) async {
    final indexed = await _localRepository.search(query, limit: limit);
    if (indexed.isNotEmpty || limit <= 0) return indexed;

    // A migrated/stale local search index must not make foods already used in
    // the diary disappear. This bounded scan is a recovery path and applies
    // the same strict token contract as catalog/community results.
    final all = await _localRepository.getFoods();
    return all
        .where((food) => _matchesLocalFood(food, query))
        .take(limit)
        .toList(growable: false);
  }

  List<Food> _mergeCommunity(
    Iterable<Food> primary,
    Iterable<Food> fallback,
    Iterable<Food> community, {
    required int limit,
  }) {
    if (limit <= 0) return const <Food>[];
    final communityRows = community.toList(growable: false);
    final reserve = communityRows.isEmpty ? 0 : (limit >= 10 ? 10 : 1);
    final result = _merge(
      primary,
      fallback,
      limit: limit - reserve,
    ).toList(growable: true);
    for (final candidate in communityRows) {
      if (result.any((existing) => _sameFoodIdentity(existing, candidate))) {
        continue;
      }
      result.add(candidate);
      if (result.length >= limit) break;
    }
    return result;
  }

  bool _sameFoodIdentity(Food a, Food b) {
    if (a.uuid == b.uuid) return true;
    return FoodSearchNormalizer.normalize(a.name) ==
            FoodSearchNormalizer.normalize(b.name) &&
        a.servingUnit.toLowerCase() == b.servingUnit.toLowerCase() &&
        (a.servingSize - b.servingSize).abs() < 0.01;
  }

  Future<List<Food>> lookupBarcode(String barcode, {int limit = 50}) async {
    return (await lookupBarcodeDetailed(barcode, limit: limit)).foods;
  }

  Future<FoodRuntimeBarcodeResult> lookupBarcodeJourney(
    String rawBarcode, {
    int limit = 50,
  }) async {
    final identity = BarcodeIdentity.parse(rawBarcode);
    final barcode = identity.digits;
    if (!identity.isValid) {
      return FoodRuntimeBarcodeResult(
        status: FoodRuntimeBarcodeStatus.invalid,
        foods: const <Food>[],
        source: FoodRuntimeSearchSource.localOnly,
        normalizedBarcode: barcode,
      );
    }

    final localCandidates = await _localRepository.search(
      barcode,
      limit: limit,
    );
    final local = BarcodeFoodContract.deduplicateLocal(
      localCandidates,
      identity,
    );
    if (local.isNotEmpty) {
      return FoodRuntimeBarcodeResult(
        status: FoodRuntimeBarcodeStatus.found,
        foods: local,
        source: FoodRuntimeSearchSource.localOnly,
        normalizedBarcode: barcode,
      );
    }

    UnifiedFoodRepository? catalog;
    try {
      catalog = await _catalogResolver();
    } catch (_) {
      return FoodRuntimeBarcodeResult(
        status: FoodRuntimeBarcodeStatus.degraded,
        foods: const <Food>[],
        source: FoodRuntimeSearchSource.localFallback,
        normalizedBarcode: barcode,
      );
    }

    if (catalog == null) {
      return _resolveOnlineBarcode(barcode);
    }

    try {
      final resolution = await catalog.resolveBarcode(barcode);
      final food = resolution.food;
      if (food == null || !BarcodeFoodContract.acceptsUnified(food, identity)) {
        return _resolveOnlineBarcode(barcode);
      }

      return FoodRuntimeBarcodeResult(
        status: FoodRuntimeBarcodeStatus.found,
        foods: <Food>[await _localRepository.materializeUnifiedFood(food)],
        source: FoodRuntimeSearchSource.catalogAndLocal,
        normalizedBarcode: barcode,
      );
    } catch (_) {
      return FoodRuntimeBarcodeResult(
        status: FoodRuntimeBarcodeStatus.degraded,
        foods: const <Food>[],
        source: FoodRuntimeSearchSource.localFallback,
        normalizedBarcode: barcode,
      );
    } finally {
      if (catalog is CompositeFoodCatalogRepository) {
        catalog.close();
      } else if (catalog is MobileCatalogFoodRepository) {
        catalog.close();
      } else if (catalog is UsdaCoreCatalogRepository) {
        catalog.close();
      }
    }
  }

  Future<FoodRuntimeBarcodeResult> _resolveOnlineBarcode(String barcode) async {
    final remote = await _networkBarcodeResolver.resolve(barcode);
    final food = remote.food;
    final identity = BarcodeIdentity.parse(barcode);

    final productAllowsFood =
        remote.product == null ||
        BarcodeFoodContract.canMaterializeProduct(remote.product);
    if (food == null ||
        !productAllowsFood ||
        !BarcodeFoodContract.acceptsUnified(food, identity)) {
      if (remote.product != null) {
        return FoodRuntimeBarcodeResult(
          status: FoodRuntimeBarcodeStatus.identifiedProduct,
          foods: const <Food>[],
          source: FoodRuntimeSearchSource.catalogAndLocal,
          normalizedBarcode: barcode,
          product: remote.product,
        );
      }
      return FoodRuntimeBarcodeResult(
        status: FoodRuntimeBarcodeStatus.notFound,
        foods: const <Food>[],
        source: FoodRuntimeSearchSource.localOnly,
        normalizedBarcode: barcode,
      );
    }

    final materialized = await _localRepository.materializeUnifiedFood(food);

    return FoodRuntimeBarcodeResult(
      status: FoodRuntimeBarcodeStatus.found,
      foods: <Food>[materialized],
      source: FoodRuntimeSearchSource.catalogAndLocal,
      normalizedBarcode: barcode,
    );
  }

  Future<FoodRuntimeSearchResult> lookupBarcodeDetailed(
    String barcode, {
    int limit = 50,
  }) async {
    final outcome = await lookupBarcodeJourney(barcode, limit: limit);
    return FoodRuntimeSearchResult(
      foods: outcome.foods,
      source: outcome.source,
    );
  }

  List<Food> _merge(
    Iterable<Food> primary,
    Iterable<Food> fallback, {
    required int limit,
  }) {
    if (limit <= 0) return const <Food>[];
    final byIdentity = <String, Food>{};
    for (final food in <Food>[...primary, ...fallback]) {
      // External catalog rows are materialized with their stable catalog id as
      // the local UUID. Generated localized names can be partial and are not a
      // safe identity (many distinct foods used to collapse into "بط").
      final identity = food.uuid.trim().isNotEmpty
          ? food.uuid.trim()
          : '${food.barcode ?? ''}:${FoodSearchNormalizer.normalize(food.name)}';
      byIdentity.putIfAbsent(identity, () => food);
      if (byIdentity.length >= limit) break;
    }
    return byIdentity.values.toList(growable: false);
  }

  bool _matchesQuery(UnifiedFood food, String query) {
    return _matchesSearchText(
      <String>[
        food.name,
        food.arabicName ?? '',
        food.category ?? '',
        ...food.keywords,
      ].join(' '),
      query,
    );
  }

  bool _matchesLocalFood(Food food, String query) {
    return _matchesSearchText(
      <String>[
        food.name,
        food.arabicName ?? '',
        food.category ?? '',
        food.keywords,
      ].join(' '),
      query,
    );
  }

  bool _matchesSearchText(String candidate, String query) {
    final candidateTokens = FoodSearchNormalizer.tokens(candidate).toSet();
    final expandedQueries = _searchAssistance.expand(query);
    if (expandedQueries.isEmpty) return true;
    return expandedQueries.any((expanded) {
      final queryTokens = FoodSearchNormalizer.tokens(expanded);
      return queryTokens.isNotEmpty &&
          queryTokens.every(
            (token) =>
                candidateTokens.contains(token) ||
                candidateTokens.contains('${token}s'),
          );
    });
  }
}
