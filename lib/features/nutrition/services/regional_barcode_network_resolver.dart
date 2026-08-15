import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/unified_food.dart';
import '../domain/product_identity.dart';
import 'product_classifier.dart';

class RegionalBarcodeLookup {
  const RegionalBarcodeLookup({
    required this.food,
    this.product,
    required this.source,
    required this.fromCache,
  });

  final UnifiedFood? food;
  final ProductIdentity? product;
  final String source;
  final bool fromCache;
}

/// Optional online enrichment after every trusted local barcode source fails.
///
/// Open Food Facts is queried first because it is barcode-oriented and commonly
/// contains products from multiple countries. USDA remains an optional branded
/// enrichment path when BIL_USDA_API_KEY is provided through --dart-define.
/// Successful responses are cached locally for future offline use.
class RegionalBarcodeNetworkResolver {
  const RegionalBarcodeNetworkResolver({
    this.productClassifier = const ProductClassifier(),
  });

  final ProductClassifier productClassifier;

  // Provider credentials are server-side only. This empty legacy constant
  // keeps the retired parser code inert until its next mechanical cleanup.
  static const _usdaKey = '';

  Future<RegionalBarcodeLookup> resolve(String barcode) async {
    final cached = await _readCache(barcode);
    if (cached != null) {
      return RegionalBarcodeLookup(
        food: cached,
        product: ProductIdentity(
          barcode: barcode,
          kind: ProductKind.food,
          name: cached.name,
          arabicName: cached.arabicName,
          source: 'regional-cache',
          confidence: ProductIdentityConfidence.medium,
        ),
        source: 'regional-cache',
        fromCache: true,
      );
    }
    final cachedProduct = await _readProductCache(barcode);
    if (cachedProduct != null) {
      return RegionalBarcodeLookup(
        food: null,
        product: cachedProduct,
        source: 'regional-product-cache',
        fromCache: true,
      );
    }

    final trusted = await _bilBackend(barcode);
    if (trusted != null) {
      final food = trusted.$1;
      if (food != null) await _writeCache(barcode, food);
      if (food == null) await _writeProductCache(trusted.$2);
      return RegionalBarcodeLookup(
        food: food,
        product: trusted.$2,
        source: 'bil-barcode-gateway',
        fromCache: false,
      );
    }

    return const RegionalBarcodeLookup(
      food: null,
      product: null,
      source: 'not-found',
      fromCache: false,
    );
  }

  Future<(UnifiedFood?, ProductIdentity)?> _bilBackend(String barcode) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'barcode-lookup',
        body: <String, Object?>{'gtin': barcode},
      );
      if (response.status != 200 || response.data is! Map) return null;
      final root = Map<String, dynamic>.from(response.data as Map);
      final payloadRaw = root['payload'];
      if (root['status'] != 'found' || payloadRaw is! Map) return null;
      final payload = Map<String, dynamic>.from(payloadRaw);
      final name = payload['name']?.toString().trim() ?? '';
      if (name.isEmpty) return null;
      final nutrientRows = payload['nutrients'] is List
          ? payload['nutrients'] as List
          : const <Object?>[];
      double? nutrient(String expected) {
        for (final raw in nutrientRows) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          if ((row['name']?.toString().toLowerCase() ?? '') ==
              expected.toLowerCase()) {
            return (row['amount'] as num?)?.toDouble();
          }
        }
        return null;
      }

      final food = UnifiedFood(
        id: 'usda:${payload['fdc_id'] ?? barcode}',
        name: name,
        barcode: barcode,
        category: 'regional branded',
        serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
        nutrients: <FoodNutrient, NutrientAmount>{
          FoodNutrient.calories: _amount(nutrient('Energy')),
          FoodNutrient.protein: _amount(nutrient('Protein')),
          FoodNutrient.carbohydrates: _amount(
            nutrient('Carbohydrate, by difference'),
          ),
          FoodNutrient.fat: _amount(nutrient('Total lipid (fat)')),
          FoodNutrient.fiber: _amount(nutrient('Fiber, total dietary')),
          FoodNutrient.sodium: _amount(nutrient('Sodium, Na')),
          FoodNutrient.potassium: _amount(nutrient('Potassium, K')),
        },
        source: FoodDataSource.branded,
        sourceLabel: 'BIL verified barcode gateway — USDA',
        verified: true,
        isCustom: false,
        updatedAt: DateTime.now(),
      );
      return (
        food,
        ProductIdentity(
          barcode: barcode,
          kind: ProductKind.food,
          name: name,
          brand: payload['brand']?.toString(),
          source: 'BIL verified barcode gateway',
          confidence: ProductIdentityConfidence.high,
        ),
      );
    } on Object {
      return null;
    }
  }

  // Retained only for cache-schema migration compatibility; never called by
  // the production resolver, which is server-gated above.
  // ignore: unused_element
  Future<(UnifiedFood?, ProductIdentity)?> _openFacts(String barcode) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v3/product/$barcode',
      <String, String>{
        'product_type': 'all',
        'fields':
            'code,product_type,product_name,product_name_ar,brands,categories,categories_tags,labels_tags,nutriments,serving_quantity',
      },
    );
    final json = await _getJson(uri);
    if (json == null || (json['status'] != 'success' && json['status'] != 1)) {
      return null;
    }
    final product = json['product'];
    if (product is! Map<String, dynamic>) return null;
    final name = (product['product_name'] as String?)?.trim();
    final brand = (product['brands'] as String?)?.trim();
    final displayName = name?.isNotEmpty == true
        ? name!
        : brand?.isNotEmpty == true
        ? brand!
        : 'Recognized product';
    final kind = productClassifier.classify(product, displayName);
    final identity = ProductIdentity(
      barcode: barcode,
      kind: kind,
      name: displayName,
      arabicName: (product['product_name_ar'] as String?)?.trim(),
      brand: brand,
      source: 'Open Facts',
      confidence: product['product_type'] != null
          ? ProductIdentityConfidence.high
          : ProductIdentityConfidence.medium,
    );
    if (!identity.hasNutritionUse || name == null || name.isEmpty) {
      return (null, identity);
    }
    final nutrients = product['nutriments'] is Map<String, dynamic>
        ? product['nutriments'] as Map<String, dynamic>
        : const <String, dynamic>{};

    double? value(String key) {
      final raw = nutrients[key];
      return raw is num ? raw.toDouble() : double.tryParse('$raw');
    }

    final hasCoreNutrition = <String>[
      'energy-kcal_100g',
      'proteins_100g',
      'carbohydrates_100g',
      'fat_100g',
    ].any((key) => value(key) != null);
    if (!hasCoreNutrition) return (null, identity);

    final food = UnifiedFood(
      id: 'off:$barcode',
      name: name,
      arabicName: (product['product_name_ar'] as String?)?.trim(),
      category: 'regional branded',
      keywords: <String>[
        if ((product['brands'] as String?)?.trim().isNotEmpty == true)
          product['brands'] as String,
      ],
      barcode: barcode,
      serving: FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: _amount(value('energy-kcal_100g')),
        FoodNutrient.protein: _amount(value('proteins_100g')),
        FoodNutrient.carbohydrates: _amount(value('carbohydrates_100g')),
        FoodNutrient.fat: _amount(value('fat_100g')),
        FoodNutrient.fiber: _amount(value('fiber_100g')),
        FoodNutrient.sugar: _amount(value('sugars_100g')),
        FoodNutrient.sodium: _amount(
          value('sodium_100g') == null ? null : value('sodium_100g')! * 1000,
        ),
        FoodNutrient.potassium: _amount(value('potassium_100g')),
      },
      source: FoodDataSource.branded,
      sourceLabel: 'Open Food Facts',
      verified: false,
      isCustom: false,
      updatedAt: DateTime.now(),
    );
    return (food, identity);
  }

  // ignore: unused_element
  Future<UnifiedFood?> _usda(String barcode) async {
    final uri = Uri.https(
      'api.nal.usda.gov',
      '/fdc/v1/foods/search',
      <String, String>{
        'api_key': _usdaKey,
        'query': barcode,
        'dataType': 'Branded',
        'pageSize': '5',
      },
    );
    final json = await _getJson(uri);
    final foods = json?['foods'];
    if (foods is! List || foods.isEmpty) return null;
    final item = foods.first;
    if (item is! Map<String, dynamic>) return null;
    final description = (item['description'] as String?)?.trim();
    if (description == null || description.isEmpty) return null;
    final nutrients = item['foodNutrients'] is List
        ? item['foodNutrients'] as List
        : const <Object?>[];

    double? nutrient(String name) {
      for (final raw in nutrients) {
        if (raw is! Map<String, dynamic>) continue;
        if ((raw['nutrientName'] as String?)?.toLowerCase() ==
            name.toLowerCase()) {
          final value = raw['value'];
          return value is num ? value.toDouble() : double.tryParse('$value');
        }
      }
      return null;
    }

    return UnifiedFood(
      id: 'usda:${item['fdcId']}',
      name: description,
      barcode: barcode,
      category: 'regional branded',
      serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: _amount(nutrient('Energy')),
        FoodNutrient.protein: _amount(nutrient('Protein')),
        FoodNutrient.carbohydrates: _amount(
          nutrient('Carbohydrate, by difference'),
        ),
        FoodNutrient.fat: _amount(nutrient('Total lipid (fat)')),
        FoodNutrient.fiber: _amount(nutrient('Fiber, total dietary')),
        FoodNutrient.sodium: _amount(nutrient('Sodium, Na')),
        FoodNutrient.potassium: _amount(nutrient('Potassium, K')),
      },
      source: FoodDataSource.branded,
      sourceLabel: 'USDA FoodData Central',
      verified: true,
      isCustom: false,
      updatedAt: DateTime.now(),
    );
  }

  NutrientAmount _amount(double? value) => value == null
      ? const NutrientAmount.missing()
      : NutrientAmount.known(value);

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'BIL/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != 200) return null;
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<File> _cacheFile(String barcode) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'regional_barcode_cache'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return File(p.join(directory.path, '$barcode.json'));
  }

  Future<File> _productCacheFile(String barcode) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'regional_product_cache'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return File(p.join(directory.path, '$barcode.json'));
  }

  Future<ProductIdentity?> _readProductCache(String barcode) async {
    try {
      final file = await _productCacheFile(barcode);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return ProductIdentity(
        barcode: barcode,
        kind: ProductKind.values.byName(json['kind'] as String),
        name: json['name'] as String,
        arabicName: json['arabic_name'] as String?,
        brand: json['brand'] as String?,
        source: json['source'] as String,
        confidence: ProductIdentityConfidence.values.byName(
          json['confidence'] as String,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeProductCache(ProductIdentity product) async {
    try {
      final file = await _productCacheFile(product.barcode);
      await file.writeAsString(
        jsonEncode({
          'schema_version': 1,
          'kind': product.kind.name,
          'name': product.name,
          'arabic_name': product.arabicName,
          'brand': product.brand,
          'source': product.source,
          'confidence': product.confidence.name,
        }),
        flush: true,
      );
    } catch (_) {
      // Cache failure must never turn a successful identification into failure.
    }
  }

  Future<UnifiedFood?> _readCache(String barcode) async {
    try {
      final file = await _cacheFile(barcode);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return _foodFromCache(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String barcode, UnifiedFood food) async {
    try {
      final file = await _cacheFile(barcode);
      await file.writeAsString(jsonEncode(_foodToCache(food)), flush: true);
    } catch (_) {
      // Cache failure must never break barcode resolution.
    }
  }

  Map<String, Object?> _foodToCache(UnifiedFood food) => <String, Object?>{
    'id': food.id,
    'name': food.name,
    'arabicName': food.arabicName,
    'barcode': food.barcode,
    'sourceLabel': food.sourceLabel,
    'verified': food.verified,
    'nutrients': <String, Object?>{
      for (final nutrient in FoodNutrient.values)
        nutrient.name: food.knownValue(nutrient),
    },
  };

  UnifiedFood _foodFromCache(Map<String, dynamic> json) {
    final nutrients = json['nutrients'] is Map<String, dynamic>
        ? json['nutrients'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return UnifiedFood(
      id: json['id'] as String,
      name: json['name'] as String,
      arabicName: json['arabicName'] as String?,
      barcode: json['barcode'] as String?,
      category: 'regional branded',
      serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        for (final nutrient in FoodNutrient.values)
          nutrient: _amount(
            nutrients[nutrient.name] is num
                ? (nutrients[nutrient.name] as num).toDouble()
                : null,
          ),
      },
      source: FoodDataSource.branded,
      sourceLabel: json['sourceLabel'] as String? ?? 'regional-cache',
      verified: json['verified'] == true,
      isCustom: false,
      updatedAt: DateTime.now(),
    );
  }
}
