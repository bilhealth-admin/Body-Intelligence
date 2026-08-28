import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_localizations.dart';
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

    final trusted = await _bilBackend(
      barcode,
      AppLocalizations.activeLocale.toLanguageTag(),
    );
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

  Future<(UnifiedFood?, ProductIdentity)?> _bilBackend(
    String barcode,
    String localeTag,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'barcode-lookup',
        body: <String, Object?>{'gtin': barcode, 'locale': localeTag},
      );
      if (response.status != 200 || response.data is! Map) return null;
      final root = Map<String, dynamic>.from(response.data as Map);
      final payloadRaw = root['payload'];
      if (root['status'] != 'found' || payloadRaw is! Map) return null;
      final payload = Map<String, dynamic>.from(payloadRaw);
      final languageCode = localeTag.toLowerCase().split(RegExp('[-_]')).first;
      final names = payload['names'] is Map
          ? Map<String, dynamic>.from(payload['names'] as Map)
          : const <String, dynamic>{};
      final localizedName = names[languageCode]?.toString().trim() ?? '';
      final name = localizedName.isNotEmpty
          ? localizedName
          : payload['name']?.toString().trim() ?? '';
      if (name.isEmpty) return null;

      final provider =
          payload['provider']?.toString() ??
          root['source']?.toString() ??
          'bil';
      final kind = provider == 'usda'
          ? ProductKind.food
          : productClassifier.classify(payload, name);
      final identity = ProductIdentity(
        barcode: barcode,
        kind: kind,
        name: name,
        arabicName:
            names['ar']?.toString().trim() ??
            payload['arabic_name']?.toString().trim(),
        brand: payload['brand']?.toString().trim(),
        source: provider == 'open_facts'
            ? 'Open Facts universal catalog'
            : 'BIL verified barcode gateway — USDA',
        confidence: payload['product_type'] != null || provider == 'usda'
            ? ProductIdentityConfidence.high
            : ProductIdentityConfidence.medium,
      );
      final food = _foodFromGatewayPayload(
        barcode: barcode,
        payload: payload,
        identity: identity,
        provider: provider,
      );
      return (food, identity);
    } on Object {
      return null;
    }
  }

  UnifiedFood? _foodFromGatewayPayload({
    required String barcode,
    required Map<String, dynamic> payload,
    required ProductIdentity identity,
    required String provider,
  }) {
    if (!identity.hasNutritionUse) return null;
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

    final calories = nutrient('Energy');
    if (calories == null) return null;
    final sourceLabel = provider == 'open_facts'
        ? 'Open Food Facts'
        : 'BIL verified barcode gateway — USDA';
    return UnifiedFood(
      id: provider == 'open_facts'
          ? 'off:$barcode'
          : 'usda:${payload['fdc_id'] ?? barcode}',
      name: identity.name,
      arabicName: identity.arabicName,
      barcode: barcode,
      category: identity.kind.name,
      keywords: <String>[
        if (identity.brand?.isNotEmpty == true) identity.brand!,
      ],
      serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: <FoodNutrient, NutrientAmount>{
        FoodNutrient.calories: _amount(calories),
        FoodNutrient.protein: _amount(nutrient('Protein')),
        FoodNutrient.carbohydrates: _amount(
          nutrient('Carbohydrate, by difference'),
        ),
        FoodNutrient.fat: _amount(nutrient('Total lipid (fat)')),
        FoodNutrient.fiber: _amount(nutrient('Fiber, total dietary')),
        FoodNutrient.sugar: _amount(nutrient('Sugars, total')),
        FoodNutrient.sodium: _amount(nutrient('Sodium, Na')),
        FoodNutrient.potassium: _amount(nutrient('Potassium, K')),
        FoodNutrient.calcium: _amount(nutrient('Calcium, Ca')),
        FoodNutrient.magnesium: _amount(nutrient('Magnesium, Mg')),
        FoodNutrient.phosphorus: _amount(nutrient('Phosphorus, P')),
        FoodNutrient.iron: _amount(nutrient('Iron, Fe')),
        FoodNutrient.vitaminC: _amount(nutrient('Vitamin C')),
      },
      source: FoodDataSource.branded,
      sourceLabel: sourceLabel,
      verified: provider == 'usda',
      isCustom: false,
      updatedAt: DateTime.now(),
    );
  }

  NutrientAmount _amount(double? value) => value == null
      ? const NutrientAmount.missing()
      : NutrientAmount.known(value);

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
