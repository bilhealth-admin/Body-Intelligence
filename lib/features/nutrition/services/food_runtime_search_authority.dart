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
import 'food_search_text_matcher.dart';
import 'regional_barcode_network_resolver.dart';
import 'trusted_food_network_search_resolver.dart';

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
  static const FoodSearchTextMatcher _textMatcher = FoodSearchTextMatcher();
  final FoodRepository _localRepository;
  final MobileCatalogRepositoryResolver _catalogResolver;
  final CommunityFoodSearchResolver? communitySearchResolver;
  final RegionalBarcodeNetworkResolver _networkBarcodeResolver;
  final TrustedFoodNetworkSearchResolver networkSearchResolver;

  FoodRuntimeSearchAuthority(
    this._localRepository, {
    MobileCatalogRepositoryResolver? catalogResolver,
    this.communitySearchResolver,
    this._networkBarcodeResolver = const RegionalBarcodeNetworkResolver(),
    this.networkSearchResolver = const TrustedFoodNetworkSearchResolver(),
  }) : _catalogResolver =
           catalogResolver ?? ActiveMobileCatalogResolver().openIfAvailable;

  Future<List<Food>> search(String query, {int limit = 50}) async {
    return (await searchDetailed(query, limit: limit)).foods;
  }

  /// Returns every local row whose normalized name is exactly [query].
  ///
  /// This deliberately runs before semantic search deduplication. Importers
  /// need to distinguish a single authoritative local match from two separate
  /// foods that happen to share a name and serving, rather than silently
  /// choosing one of them.
  Future<List<Food>> findExactLocalNameCandidates(
    String query, {
    int limit = 8,
  }) async {
    if (limit <= 0) return const <Food>[];
    final normalized = FoodSearchNormalizer.normalize(query);
    if (normalized.isEmpty) return const <Food>[];
    final candidates = await _searchLocal(query, limit: limit);
    return candidates
        .where(
          (food) => FoodSearchNormalizer.normalize(food.name) == normalized,
        )
        .toList(growable: false);
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
      final network = local.isEmpty && community.isEmpty
          ? await _loadTrustedNetwork(query, limit: limit)
          : const <Food>[];
      return FoodRuntimeSearchResult(
        foods: _mergeCommunity(
          local,
          network,
          community,
          query: query,
          limit: limit,
        ),
        source: network.isNotEmpty || community.isNotEmpty
            ? FoodRuntimeSearchSource.catalogAndLocal
            : FoodRuntimeSearchSource.localFallback,
      );
    }

    if (catalog == null) {
      final network = local.isEmpty && community.isEmpty
          ? await _loadTrustedNetwork(query, limit: limit)
          : const <Food>[];
      return FoodRuntimeSearchResult(
        foods: _mergeCommunity(
          local,
          network,
          community,
          query: query,
          limit: limit,
        ),
        source: network.isNotEmpty || community.isNotEmpty
            ? FoodRuntimeSearchSource.catalogAndLocal
            : FoodRuntimeSearchSource.localOnly,
      );
    }

    try {
      final expandedLimit = (limit * 5).clamp(limit, 250);
      final hits = await catalog.searchUnified(query, limit: expandedLimit);
      final matchedHits = hits
          .map((hit) => (hit: hit, match: _matchQuery(hit.food, query)))
          .where((entry) => entry.match.matches)
          .toList(growable: false);
      final rankedHits =
          _textMatcher.suppressIncompleteTokenPrefixes(
            matchedHits,
            (entry) => entry.match,
          )..sort((left, right) {
            final matchOrder = right.match.rank.compareTo(left.match.rank);
            if (matchOrder != 0) return matchOrder;
            return right.hit.score.compareTo(left.hit.score);
          });
      final materialized = <Food>[];
      for (final entry in rankedHits) {
        materialized.add(
          await _localRepository.materializeUnifiedFood(entry.hit.food),
        );
        if (materialized.length >= limit) break;
      }
      final current = _mergeCommunity(
        materialized,
        local,
        community,
        query: query,
        limit: limit,
      );
      final network = current.isEmpty
          ? await _loadTrustedNetwork(query, limit: limit)
          : const <Food>[];
      return FoodRuntimeSearchResult(
        foods: network.isEmpty
            ? current
            : _mergeCommunity(
                network,
                current,
                community,
                query: query,
                limit: limit,
              ),
        source: FoodRuntimeSearchSource.catalogAndLocal,
      );
    } catch (_) {
      final network = local.isEmpty && community.isEmpty
          ? await _loadTrustedNetwork(query, limit: limit)
          : const <Food>[];
      return FoodRuntimeSearchResult(
        foods: _mergeCommunity(
          local,
          network,
          community,
          query: query,
          limit: limit,
        ),
        source: network.isNotEmpty || community.isNotEmpty
            ? FoodRuntimeSearchSource.catalogAndLocal
            : FoodRuntimeSearchSource.localFallback,
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

  Future<List<Food>> _loadTrustedNetwork(
    String query, {
    required int limit,
  }) async {
    if (limit <= 0) return const <Food>[];
    try {
      final unified = await networkSearchResolver.search(
        query,
        limit: limit < 20 ? limit : 20,
      );
      final foods = <Food>[];
      for (final food in _rankUnifiedFoods(unified, query)) {
        foods.add(await _localRepository.materializeUnifiedFood(food));
        if (foods.length >= limit) break;
      }
      return foods;
    } catch (_) {
      return const <Food>[];
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
      for (final food in _rankUnifiedFoods(unified, query)) {
        foods.add(await _localRepository.materializeUnifiedFood(food));
      }
      return foods;
    } catch (_) {
      return const <Food>[];
    }
  }

  Future<List<Food>> _searchLocal(String query, {required int limit}) async {
    final expandedLimit = (limit * 5).clamp(limit, 250);
    final indexed = _rankLocalFoods(
      await _localRepository.search(query, limit: expandedLimit),
      query,
    ).take(limit).toList(growable: false);
    if (indexed.isNotEmpty || limit <= 0) return indexed;

    // A migrated/stale local search index must not make foods already used in
    // the diary disappear. This bounded scan is a recovery path and applies
    // the same strict token contract as catalog/community results.
    final all = await _localRepository.getFoods();
    return _rankLocalFoods(all, query).take(limit).toList(growable: false);
  }

  List<Food> _mergeCommunity(
    Iterable<Food> primary,
    Iterable<Food> fallback,
    Iterable<Food> community, {
    required String query,
    required int limit,
  }) {
    if (limit <= 0) return const <Food>[];
    final communityRows = community.toList(growable: false);
    final reserve = communityRows.isEmpty ? 0 : (limit >= 10 ? 10 : 1);
    final nonCommunity = <Food>[];
    for (final candidate in <Food>[...primary, ...fallback]) {
      if (nonCommunity.any(
        (existing) => _sameFoodIdentity(existing, candidate),
      )) {
        continue;
      }
      nonCommunity.add(candidate);
    }
    final result = _rankLocalFoods(
      nonCommunity,
      query,
    ).take(limit - reserve).toList(growable: true);
    for (final candidate in _rankLocalFoods(communityRows, query)) {
      if (result.any((existing) => _sameFoodIdentity(existing, candidate))) {
        continue;
      }
      result.add(candidate);
      if (result.length >= limit) break;
    }
    return _rankLocalFoods(result, query).take(limit).toList(growable: false);
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
      // A damaged, locked, or stale offline catalog must not terminate a real
      // barcode journey. The BIL gateway is the authoritative final source
      // (Open Food Facts first, then USDA when configured server-side), so
      // attempt it exactly as we do for a clean local miss.
      return _resolveOnlineBarcode(barcode);
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
      // The installed catalog can fail independently of the network gateway
      // (for example while an offline pack is being replaced). Keep the real
      // barcode journey alive instead of presenting a false local-only miss.
      return _resolveOnlineBarcode(barcode);
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

  FoodSearchTextMatch _matchesSearchText({
    required String query,
    required String primaryName,
    String? arabicName,
    String? category,
    Iterable<String> keywords = const <String>[],
  }) {
    return _textMatcher.match(
      query: query,
      queryVariants: _searchAssistance.expand(query),
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
    final ranked = _textMatcher.suppressIncompleteTokenPrefixes(
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
    final ranked = _textMatcher.suppressIncompleteTokenPrefixes(
      matched,
      (entry) => entry.match,
    )..sort((left, right) => right.match.rank.compareTo(left.match.rank));
    return ranked.map((entry) => entry.food).toList(growable: false);
  }
}
