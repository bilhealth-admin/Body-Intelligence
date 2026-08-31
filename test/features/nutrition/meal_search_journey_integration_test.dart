import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/food_repository.dart';
import 'package:body_intelligence_log/features/nutrition/domain/unified_food.dart';
import 'package:body_intelligence_log/features/nutrition/presentation/food_barcode_scanner_page.dart';
import 'package:body_intelligence_log/features/nutrition/repositories/usda_core_catalog_repository.dart';
import 'package:body_intelligence_log/features/nutrition/services/food_runtime_search_authority.dart';
import 'package:body_intelligence_log/features/nutrition/services/trusted_food_network_search_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  late AppDatabase database;
  late FoodRepository local;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    local = FoodRepository(database);
  });

  tearDown(() => database.close());

  test(
    'incremental text uses local plus bundled SQLite core and trusted gateway only on miss',
    () async {
      await local.addFood(
        name: 'Apple',
        category: 'fruit',
        calories: 52,
        protein: .3,
        carbs: 14,
        fats: .2,
        servingSize: 100,
        servingUnit: 'g',
      );
      await local.addFood(
        name: 'Applebees Bacon',
        category: 'restaurant',
        calories: 100,
        protein: 5,
        carbs: 5,
        fats: 5,
        servingSize: 100,
        servingUnit: 'g',
      );
      final gateway = _TrustedGatewaySpy(
        _food(id: 'gateway:zzqx-meal', name: 'Zzqx meal'),
      );
      final authority = FoodRuntimeSearchAuthority(
        local,
        catalogResolver: () async => UsdaCoreCatalogRepository.open(
          'assets/catalogs/bil_food_core.sqlite',
        ),
        networkSearchResolver: gateway,
      );

      for (final query in const <String>['a', 'ap', 'app', 'appl', 'apple']) {
        final result = await authority.searchDetailed(query, limit: 8);
        expect(
          result.foods.any(
            (food) => food.name.toLowerCase().startsWith('apple'),
          ),
          isTrue,
          reason: '$query: ${result.foods.map((food) => food.name).toList()}',
        );
      }
      expect(gateway.calls, 0);

      final completed = await authority.searchDetailed('apple', limit: 8);
      expect(completed.foods.map((food) => food.name), contains('Apple'));
      expect(
        completed.foods.map((food) => food.name),
        isNot(contains('Applebees Bacon')),
      );
      expect(gateway.calls, 0);

      final enriched = await authority.searchDetailed('zzqx meal', limit: 8);
      expect(gateway.calls, 1);
      expect(enriched.foods.single.uuid, 'gateway:zzqx-meal');
      expect(enriched.source, FoodRuntimeSearchSource.catalogAndLocal);
    },
  );

  test(
    'manual localized digits and decoded image value converge on one GTIN journey',
    () async {
      await local.addFood(
        name: 'Fixture product',
        category: 'branded',
        barcode: '4006381333931',
        calories: 100,
        protein: 5,
        carbs: 12,
        fats: 3,
        servingSize: 100,
        servingUnit: 'g',
        source: 'branded',
        verified: true,
      );
      final authority = FoodRuntimeSearchAuthority(
        local,
        catalogResolver: () async => null,
      );
      const decodedCapture = BarcodeCapture(
        barcodes: <Barcode>[
          Barcode(rawValue: ' 4006381333931 ', format: BarcodeFormat.ean13),
        ],
      );

      final manual = await authority.lookupBarcodeJourney('٤٠٠-٦٣٨١٣٣٣٩٣١');
      final decoded = await authority.lookupBarcodeJourney(
        barcodeRawValueFromCapture(decodedCapture)!,
      );

      expect(manual.normalizedBarcode, '4006381333931');
      expect(decoded.normalizedBarcode, manual.normalizedBarcode);
      expect(decoded.status, FoodRuntimeBarcodeStatus.found);
      expect(decoded.foods.single.id, manual.foods.single.id);
    },
  );

  test('all four meal types use the same latest-query search surface', () {
    final page = File(
      'lib/features/daily_log/daily_log_page.dart',
    ).readAsStringSync();
    final entry = File(
      'lib/features/daily_log/daily_log_meal_entry.dart',
    ).readAsStringSync();
    final search = File(
      'lib/features/daily_log/daily_log_meal_search.dart',
    ).readAsStringSync();

    for (final mealType in const <String>[
      'breakfast',
      'lunch',
      'dinner',
      'snack',
    ]) {
      expect(page, contains("'$mealType'"), reason: mealType);
    }
    expect(RegExp(r'\bSearchAnchor\(').allMatches(entry), hasLength(1));
    expect(entry, contains('_mealQuerySuggestions(controller, query, locale)'));
    expect(search, contains('effectiveQuery = controller.text.trim()'));
    expect(search, contains('final latestQuery = controller.text.trim()'));
  });

  test('camera and gallery captures share the same raw-value callback', () {
    final scanner = File(
      'lib/features/nutrition/presentation/food_barcode_scanner_page.dart',
    ).readAsStringSync();
    final dailyCapture = File(
      'lib/features/daily_log/daily_log_capture_actions.dart',
    ).readAsStringSync();

    expect(scanner, contains('controller.analyzeImage('));
    expect(scanner, contains('ImageSource.gallery'));
    expect(
      scanner,
      contains('_lookupBarcodeValue(barcodeRawValueFromCapture(capture))'),
    );
    expect(scanner, contains('_lookupBarcodeValue(value)'));
    expect(dailyCapture, contains(".lookupBarcodeJourney(rawBarcode)"));
  });
}

class _TrustedGatewaySpy extends TrustedFoodNetworkSearchResolver {
  _TrustedGatewaySpy(this.food);

  final UnifiedFood food;
  int calls = 0;

  @override
  Future<List<UnifiedFood>> search(String query, {int limit = 10}) async {
    calls += 1;
    return <UnifiedFood>[food];
  }
}

UnifiedFood _food({required String id, required String name}) {
  return UnifiedFood(
    id: id,
    name: name,
    category: 'food',
    serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
    nutrients: const <FoodNutrient, NutrientAmount>{
      FoodNutrient.calories: NutrientAmount.known(52),
      FoodNutrient.protein: NutrientAmount.known(.3),
      FoodNutrient.carbohydrates: NutrientAmount.known(14),
      FoodNutrient.fat: NutrientAmount.known(.2),
    },
    source: FoodDataSource.foundation,
    sourceLabel: 'BIL trusted gateway',
    verified: true,
    isCustom: false,
  );
}
