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
import 'regional_barcode_network_resolver.dart';

typedef MobileCatalogRepositoryResolver =
    Future<UnifiedFoodRepository?> Function();

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
  final FoodRepository _localRepository;
  final MobileCatalogRepositoryResolver _catalogResolver;
  final RegionalBarcodeNetworkResolver _networkBarcodeResolver;

  FoodRuntimeSearchAuthority(
    this._localRepository, {
    MobileCatalogRepositoryResolver? catalogResolver,
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

    final local = await _localRepository.search(query, limit: limit);

    UnifiedFoodRepository? catalog;
    try {
      catalog = await _catalogResolver();
    } catch (_) {
      return FoodRuntimeSearchResult(
        foods: local,
        source: FoodRuntimeSearchSource.localFallback,
      );
    }

    if (catalog == null) {
      return FoodRuntimeSearchResult(
        foods: local,
        source: FoodRuntimeSearchSource.localOnly,
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
        foods: _merge(materialized, local, limit: limit),
        source: FoodRuntimeSearchSource.catalogAndLocal,
      );
    } catch (_) {
      return FoodRuntimeSearchResult(
        foods: local,
        source: FoodRuntimeSearchSource.localFallback,
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
    final byIdentity = <String, Food>{};
    for (final food in <Food>[...primary, ...fallback]) {
      final normalizedName = food.name.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      final arabicName = (food.arabicName ?? '')
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ');
      final identity = arabicName.isEmpty ? normalizedName : arabicName;
      byIdentity.putIfAbsent(identity, () => food);
      if (byIdentity.length >= limit) break;
    }
    return byIdentity.values.toList(growable: false);
  }

  bool _matchesQuery(UnifiedFood food, String query) {
    final queryTokens = FoodSearchNormalizer.tokens(query);
    if (queryTokens.isEmpty) return true;
    final candidateTokens = FoodSearchNormalizer.tokens(
      <String>[
        food.name,
        food.arabicName ?? '',
        food.category ?? '',
        ...food.keywords,
      ].join(' '),
    ).toSet();
    return queryTokens.every(
      (token) =>
          candidateTokens.contains(token) ||
          candidateTokens.contains('${token}s'),
    );
  }
}
