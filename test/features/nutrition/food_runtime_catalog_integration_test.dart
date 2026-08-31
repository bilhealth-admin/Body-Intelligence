import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/barcode_identity.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/unified_food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_deduplication_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_foundation_integrity_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_migration_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_quality_engine.dart';
import 'package:body_intelligence_log/features/nutrition/services/offline_barcode_resolver.dart';
import 'package:body_intelligence_log/features/nutrition/services/offline_food_search_pipeline.dart';
import 'package:body_intelligence_log/features/nutrition/services/regional_barcode_network_resolver.dart';
import 'package:body_intelligence_log/features/nutrition/services/trusted_food_network_search_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late FoodRepository local;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    local = FoodRepository(database);
  });

  tearDown(() => database.close());

  test(
    'catalog text result is materialized for meal-compatible local use',
    () async {
      final catalogFood = _food(
        id: 'bil-usda-apple',
        name: 'Apple',
        arabicName: 'تفاح',
      );
      final authority = FoodRuntimeSearchAuthority(
        local,
        catalogResolver: () async => _FakeCatalog([catalogFood]),
      );

      final results = await authority.search('apple');

      expect(results, hasLength(1));
      expect(results.single.uuid, 'bil-usda-apple');
      expect(results.single.source, 'bil-mobile-catalog');
      expect(results.single.isCustom, isFalse);

      final repeated = await authority.search('apple');
      expect(repeated, hasLength(1));
      expect((await local.getFoods()), hasLength(1));
    },
  );

  test('missing catalog falls back to the existing local repository', () async {
    await local.addFood(
      name: 'Local milk',
      category: 'food',
      calories: 10,
      protein: 1,
      carbs: 1,
      fats: 1,
      servingSize: 100,
      servingUnit: 'g',
    );
    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async => null,
    );

    final results = await authority.search('milk');

    expect(results.single.name, 'Local milk');
  });

  test(
    'barcode resolves from catalog only after local fallback misses',
    () async {
      final catalogFood = _food(
        id: 'bil-branded-1',
        name: 'Catalog product',
        barcode: '6221234567891',
      );
      final authority = FoodRuntimeSearchAuthority(
        local,
        catalogResolver: () async => _FakeCatalog([catalogFood]),
      );

      final results = await authority.lookupBarcode('6221234567891');

      expect(results, hasLength(1));
      expect(results.single.uuid, 'bil-branded-1');
      expect(results.single.barcode, '6221234567891');
    },
  );

  test(
    'empty query preserves personalized local behavior without catalog call',
    () async {
      var catalogCalls = 0;
      await local.addFood(
        name: 'Local',
        category: 'food',
        calories: 1,
        protein: 1,
        carbs: 1,
        fats: 1,
        servingSize: 100,
        servingUnit: 'g',
      );
      final authority = FoodRuntimeSearchAuthority(
        local,
        catalogResolver: () async {
          catalogCalls += 1;
          return _FakeCatalog(const []);
        },
      );

      final results = await authority.search('');

      expect(results, hasLength(1));
      expect(catalogCalls, 0);
    },
  );

  test('detailed search reports catalog provenance', () async {
    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async =>
          _FakeCatalog([_food(id: 'bil-usda-orange', name: 'Orange')]),
    );

    final outcome = await authority.searchDetailed('orange');

    expect(outcome.source, FoodRuntimeSearchSource.catalogAndLocal);
    expect(outcome.catalogUsed, isTrue);
    expect(outcome.degraded, isFalse);
    expect(outcome.foods.single.uuid, 'bil-usda-orange');
  });

  test('catalog matching accepts a supported non-English query', () async {
    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async =>
          _FakeCatalog([_food(id: 'bil-usda-apple', name: 'Apple')]),
    );

    for (final query in ['яблоко', 'りんご', '苹果', 'सेब']) {
      final outcome = await authority.searchDetailed(query);
      expect(outcome.foods.single.uuid, 'bil-usda-apple', reason: query);
    }
  });

  test(
    'materialization repairs missing nutrient evidence and stale label',
    () async {
      await local.materializeUnifiedFood(
        _food(id: 'bil-usda-apple', name: 'Apple', arabicName: 'بط'),
      );
      final repaired = await local.materializeUnifiedFood(
        _food(
          id: 'bil-usda-apple',
          name: 'Apple',
          nutrients: const {
            FoodNutrient.calories: NutrientAmount.known(52),
            FoodNutrient.protein: NutrientAmount.known(0.3),
            FoodNutrient.carbohydrates: NutrientAmount.known(14),
            FoodNutrient.fat: NutrientAmount.known(0.2),
            FoodNutrient.potassium: NutrientAmount.known(107),
            FoodNutrient.calcium: NutrientAmount.known(6),
          },
        ),
      );

      expect(repaired.arabicName, isNull);
      expect(repaired.potassium, 107);
      expect(repaired.calcium, 6);
      expect(
        UnifiedFood.evidenceFromMask(
          repaired.nutrientEvidenceMask,
          FoodNutrient.potassium,
        ),
        isTrue,
      );
    },
  );

  test('catalog search failure degrades safely to local results', () async {
    await local.addFood(
      name: 'Local oats',
      category: 'food',
      calories: 40,
      protein: 2,
      carbs: 7,
      fats: 1,
      servingSize: 100,
      servingUnit: 'g',
    );
    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async => _ThrowingCatalog(),
    );

    final outcome = await authority.searchDetailed('oats');

    expect(outcome.source, FoodRuntimeSearchSource.localFallback);
    expect(outcome.degraded, isTrue);
    expect(outcome.foods.single.name, 'Local oats');
  });

  test(
    'trusted server search runs only after local community and catalog miss',
    () async {
      final network = _FakeNetworkSearchResolver(<UnifiedFood>[
        _food(id: 'usda:2709216', name: 'Dragon fruit, raw'),
      ]);
      final authority = FoodRuntimeSearchAuthority(
        local,
        catalogResolver: () async => _FakeCatalog(const []),
        networkSearchResolver: network,
      );

      final outcome = await authority.searchDetailed('dragon fruit');

      expect(network.calls, 1);
      expect(outcome.source, FoodRuntimeSearchSource.catalogAndLocal);
      expect(outcome.foods.single.uuid, 'usda:2709216');
      expect((await local.getFoods()).single.uuid, 'usda:2709216');
    },
  );

  test('local search hit suppresses trusted network enrichment', () async {
    await local.addFood(
      name: 'Local oats',
      category: 'food',
      calories: 40,
      protein: 2,
      carbs: 7,
      fats: 1,
      servingSize: 100,
      servingUnit: 'g',
    );
    final network = _FakeNetworkSearchResolver(<UnifiedFood>[
      _food(id: 'usda:oats', name: 'Oats'),
    ]);
    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async => _FakeCatalog(const []),
      networkSearchResolver: network,
    );

    final outcome = await authority.searchDetailed('oats');

    expect(network.calls, 0);
    expect(outcome.foods.single.name, 'Local oats');
  });

  test('trusted network outage keeps the offline miss non-fatal', () async {
    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async => _ThrowingCatalog(),
      networkSearchResolver: _ThrowingNetworkSearchResolver(),
    );

    final outcome = await authority.searchDetailed('unavailable food');

    expect(outcome.source, FoodRuntimeSearchSource.localFallback);
    expect(outcome.foods, isEmpty);
  });

  test('catalog barcode failure continues to the network source', () async {
    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async => _ThrowingCatalog(),
      networkBarcodeResolver: const _NotFoundNetworkResolver(),
    );

    final outcome = await authority.lookupBarcodeDetailed('4006381333931');

    expect(outcome.source, FoodRuntimeSearchSource.localOnly);
    expect(outcome.foods, isEmpty);
  });

  test('invalid GTIN is rejected before repositories are queried', () async {
    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async => _ThrowingCatalog(),
    );

    final outcome = await authority.lookupBarcodeJourney('12345');

    expect(outcome.status, FoodRuntimeBarcodeStatus.invalid);
    expect(outcome.foods, isEmpty);
  });

  test('valid local GTIN returns found with local provenance', () async {
    await local.addFood(
      name: 'Local product',
      category: 'branded',
      barcode: '4006381333931',
      calories: 100,
      protein: 4,
      carbs: 15,
      fats: 2,
      servingSize: 100,
      servingUnit: 'g',
    );

    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async => _ThrowingCatalog(),
    );

    final outcome = await authority.lookupBarcodeJourney('4006381333931');

    expect(outcome.status, FoodRuntimeBarcodeStatus.found);
    expect(outcome.source, FoodRuntimeSearchSource.localOnly);
    expect(outcome.foods.single.name, 'Local product');
  });

  test('local, catalog, and regional network miss reports notFound', () async {
    final authority = FoodRuntimeSearchAuthority(
      local,
      catalogResolver: () async => _FakeCatalog(const []),
      networkBarcodeResolver: const _NotFoundNetworkResolver(),
    );

    final outcome = await authority.lookupBarcodeJourney('4006381333931');

    expect(outcome.status, FoodRuntimeBarcodeStatus.notFound);
    expect(outcome.degraded, isFalse);
    expect(outcome.foods, isEmpty);
  });

  test(
    'catalog exception falls through to the real network resolver',
    () async {
      final authority = FoodRuntimeSearchAuthority(
        local,
        catalogResolver: () async => _ThrowingCatalog(),
        networkBarcodeResolver: const _NotFoundNetworkResolver(),
      );

      final outcome = await authority.lookupBarcodeJourney('4006381333931');

      expect(outcome.status, FoodRuntimeBarcodeStatus.notFound);
      expect(outcome.degraded, isFalse);
    },
  );
}

class _NotFoundNetworkResolver extends RegionalBarcodeNetworkResolver {
  const _NotFoundNetworkResolver();

  @override
  Future<RegionalBarcodeLookup> resolve(String barcode) async {
    return const RegionalBarcodeLookup(
      food: null,
      source: 'test-network-miss',
      fromCache: false,
    );
  }
}

class _FakeNetworkSearchResolver extends TrustedFoodNetworkSearchResolver {
  _FakeNetworkSearchResolver(this.foods);

  final List<UnifiedFood> foods;
  int calls = 0;

  @override
  Future<List<UnifiedFood>> search(String query, {int limit = 10}) async {
    calls += 1;
    return foods.take(limit).toList(growable: false);
  }
}

class _ThrowingNetworkSearchResolver extends TrustedFoodNetworkSearchResolver {
  @override
  Future<List<UnifiedFood>> search(String query, {int limit = 10}) {
    throw StateError('network unavailable');
  }
}

UnifiedFood _food({
  required String id,
  required String name,
  String? arabicName,
  String? barcode,
  Map<FoodNutrient, NutrientAmount>? nutrients,
}) {
  return UnifiedFood(
    id: id,
    name: name,
    arabicName: arabicName,
    category: 'generic',
    barcode: barcode,
    serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
    nutrients:
        nutrients ??
        const {
          FoodNutrient.calories: NutrientAmount.known(52),
          FoodNutrient.protein: NutrientAmount.known(0.3),
          FoodNutrient.carbohydrates: NutrientAmount.known(14),
          FoodNutrient.fat: NutrientAmount.known(0.2),
        },
    source: FoodDataSource.foundation,
    sourceLabel: 'bil-mobile-catalog',
    verified: true,
    isCustom: false,
  );
}

class _FakeCatalog implements UnifiedFoodRepository {
  final List<UnifiedFood> foods;
  _FakeCatalog(this.foods);

  @override
  Future<List<FoodSearchHit>> searchUnified(
    String query, {
    int limit = 50,
  }) async => foods
      .take(limit)
      .map(
        (food) => FoodSearchHit(
          food: food,
          score: 1,
          reasons: const ['fake-catalog'],
        ),
      )
      .toList();

  @override
  Future<BarcodeResolution> resolveBarcode(String barcode) async {
    final matches = foods.where((food) => food.barcode == barcode).toList();
    return BarcodeResolution(
      identity: BarcodeIdentity.parse(barcode),
      status: matches.isEmpty
          ? BarcodeResolutionStatus.notFound
          : BarcodeResolutionStatus.resolved,
      candidates: matches,
    );
  }

  @override
  Future<List<UnifiedFood>> getAll() async => foods;
  @override
  Stream<List<UnifiedFood>> watchAll() => Stream.value(foods);
  @override
  Future<UnifiedFood?> findById(String id) async =>
      foods.where((f) => f.id == id).firstOrNull;
  @override
  Future<UnifiedFood?> findByBarcode(String barcode) async =>
      foods.where((f) => f.barcode == barcode).firstOrNull;
  @override
  Future<List<FoodDuplicateCandidate>> findDuplicateCandidates(
    UnifiedFood incoming, {
    FoodDuplicateKind minimumKind = FoodDuplicateKind.possible,
    int limit = 20,
  }) async => const [];
  @override
  Future<List<FoodMigrationPlan>> auditMigration({int limit = 1000}) async =>
      const [];
  @override
  Future<FoodQualityAudit> auditQuality({
    FoodConfidenceLevel? maximumConfidence,
    FoodQualityIssue? issue,
    int limit = 1000,
  }) async => const FoodQualityAudit(
    totalFoods: 0,
    highConfidenceCount: 0,
    mediumConfidenceCount: 0,
    lowConfidenceCount: 0,
    records: [],
  );
  @override
  Future<FoodFoundationIntegrityReport> auditFoundationIntegrity({
    int migrationLimit = 1000,
    int duplicatePairLimit = 10000,
  }) async => const FoodFoundationIntegrityReport(
    totalFoods: 0,
    sources: FoodSourceDistribution(
      foundation: 0,
      legacy: 0,
      branded: 0,
      custom: 0,
      unknown: 0,
    ),
    quality: FoodQualityAudit(
      totalFoods: 0,
      highConfidenceCount: 0,
      mediumConfidenceCount: 0,
      lowConfidenceCount: 0,
      records: [],
    ),
    migrationPlans: [],
    exactBarcodeCollisionGroups: 0,
    possibleDuplicatePairs: 0,
  );
}

class _ThrowingCatalog extends _FakeCatalog {
  _ThrowingCatalog() : super(const []);

  @override
  Future<List<FoodSearchHit>> searchUnified(String query, {int limit = 50}) {
    throw StateError('catalog search unavailable');
  }

  @override
  Future<BarcodeResolution> resolveBarcode(String barcode) {
    throw StateError('catalog barcode unavailable');
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => this.isEmpty ? null : first;
}
