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
    this.ingredients,
    required this.source,
    required this.fromCache,
  });

  final UnifiedFood? food;
  final ProductIdentity? product;
  final String? ingredients;
  final String source;
  final bool fromCache;
}

/// Optional online enrichment after every trusted local barcode source fails.
///
/// Open Food Facts is queried first because it is barcode-oriented and commonly
/// contains products from multiple countries. USDA remains an optional branded
/// enrichment path when BIL_USDA_API_KEY is configured server-side. The key is
/// never shipped in Flutter. Successful responses are cached locally for
/// future offline use.
class RegionalBarcodeNetworkResolver {
  const RegionalBarcodeNetworkResolver({
    this.productClassifier = const ProductClassifier(),
  });

  final ProductClassifier productClassifier;

  Future<RegionalBarcodeLookup> resolve(String barcode) async {
    final cached = await _readCache(barcode);
    final cachedProduct = await _readProductCache(barcode);
    // A previous build could persist a product name before nutrition was
    // available. Do not let that lossy row short-circuit the authoritative
    // gateway: try to enrich it first. A complete cached row is still safe to
    // use offline and avoids an unnecessary network request.
    final cachedHasCompleteCore =
        cached != null && _hasCompleteCoreNutrition(cached);
    final cachedHasIngredients =
        cachedProduct?.ingredients?.trim().isNotEmpty == true;
    if (cached != null && cachedHasCompleteCore && cachedHasIngredients) {
      // Keep provider identity/ingredient text alongside the nutrition cache.
      // Older installs may not have a product sidecar; the food remains valid
      // and simply omits the optional provider text in that case.
      return RegionalBarcodeLookup(
        food: cached,
        product:
            cachedProduct ??
            ProductIdentity(
              barcode: barcode,
              kind: ProductKind.food,
              name: cached.name,
              arabicName: cached.arabicName,
              source: 'regional-cache',
              confidence: ProductIdentityConfidence.medium,
            ),
        ingredients: cachedProduct?.ingredients,
        source: 'regional-cache',
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
      // The product sidecar carries ingredients and provider identity for both
      // nutrition-complete and name-only responses. This prevents a later
      // cached lookup from regressing to a bare product name.
      await _writeProductCache(trusted.$2);
      return RegionalBarcodeLookup(
        food: food,
        product: trusted.$2,
        ingredients: trusted.$3,
        source: 'bil-barcode-gateway',
        fromCache: false,
      );
    }

    // Preserve a stale cached identity only as an offline fallback. The
    // authority layer can then show the product review state instead of
    // claiming that the barcode was never recognized.
    if (cached != null) {
      return RegionalBarcodeLookup(
        food: cached,
        product:
            cachedProduct ??
            ProductIdentity(
              barcode: barcode,
              kind: ProductKind.food,
              name: cached.name,
              arabicName: cached.arabicName,
              source: 'regional-cache-stale',
              confidence: ProductIdentityConfidence.low,
            ),
        ingredients: cachedProduct?.ingredients,
        source: 'regional-cache-stale',
        fromCache: true,
      );
    }

    if (cachedProduct != null) {
      return RegionalBarcodeLookup(
        food: null,
        product: cachedProduct,
        ingredients: cachedProduct.ingredients,
        source: 'regional-product-cache',
        fromCache: true,
      );
    }

    return const RegionalBarcodeLookup(
      food: null,
      product: null,
      source: 'not-found',
      fromCache: false,
    );
  }

  Future<(UnifiedFood?, ProductIdentity, String?)?> _bilBackend(
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
      var kind = provider == 'usda'
          ? ProductKind.food
          : productClassifier.classify(payload, name);
      // Open Food Facts sometimes labels a genuine edible item as the generic
      // `product`. If it supplies an energy value, the payload is safe to
      // materialize as nutrition-backed food; retain the classifier for all
      // non-nutrition records (cosmetics, medicine, household, etc.).
      if (provider == 'open_facts' &&
          kind == ProductKind.generalProduct &&
          _hasEnergyNutrient(payload)) {
        kind = ProductKind.food;
      }
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
        ingredients: _optionalText(payload['ingredients']),
      );
      final food = _foodFromGatewayPayload(
        barcode: barcode,
        payload: payload,
        identity: identity,
        provider: provider,
      );
      return (food, identity, identity.ingredients);
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
    double? nutrient(
      String expected, [
      List<String> aliases = const <String>[],
    ]) {
      final accepted = <String>{
        expected,
        ...aliases,
      }.map(_normalizeNutrientName).toSet();
      for (final raw in nutrientRows) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        if (accepted.contains(_normalizeNutrientName(row['name']))) {
          final amount = _numeric(row['amount']);
          if (amount != null) return amount;
        }
      }
      return null;
    }

    // Keep compatibility with older gateway/cache payloads that used compact
    // nutrient names (for example `calories`, `carbs`, or `fat`) instead of
    // the USDA labels emitted by the current function. Without this aliasing,
    // a perfectly valid barcode silently degraded to a name-only review.
    final calories = nutrient('Energy', const ['calories', 'energy_kcal']);
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
        FoodNutrient.protein: _amount(nutrient('Protein', const ['proteins'])),
        FoodNutrient.carbohydrates: _amount(
          nutrient('Carbohydrate, by difference', const [
            'Carbohydrate',
            'Carbohydrates',
            'Carbs',
          ]),
        ),
        FoodNutrient.fat: _amount(
          nutrient('Total lipid (fat)', const ['Fat', 'Fats']),
        ),
        FoodNutrient.fiber: _amount(
          nutrient('Fiber, total dietary', const ['Fiber']),
        ),
        FoodNutrient.sugar: _amount(
          nutrient('Sugars, total', const ['Sugar', 'Sugars']),
        ),
        FoodNutrient.sodium: _amount(nutrient('Sodium, Na', const ['Sodium'])),
        FoodNutrient.potassium: _amount(
          nutrient('Potassium, K', const ['Potassium']),
        ),
        FoodNutrient.calcium: _amount(
          nutrient('Calcium, Ca', const ['Calcium']),
        ),
        FoodNutrient.magnesium: _amount(
          nutrient('Magnesium, Mg', const ['Magnesium']),
        ),
        FoodNutrient.phosphorus: _amount(
          nutrient('Phosphorus, P', const ['Phosphorus']),
        ),
        FoodNutrient.iron: _amount(nutrient('Iron, Fe', const ['Iron'])),
        FoodNutrient.vitaminC: _amount(
          nutrient('Vitamin C', const ['Vitamin C (ascorbic acid)']),
        ),
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

  bool _hasCompleteCoreNutrition(UnifiedFood food) => const <FoodNutrient>[
    FoodNutrient.calories,
    FoodNutrient.protein,
    FoodNutrient.carbohydrates,
    FoodNutrient.fat,
  ].every(food.hasEvidence);

  String _normalizeNutrientName(Object? value) => (value?.toString() ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  double? _numeric(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    final parsed = double.tryParse(value?.toString().trim() ?? '');
    return parsed != null && parsed.isFinite ? parsed : null;
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
        ingredients: json['ingredients'] as String?,
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
          'ingredients': product.ingredients,
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

  String? _optionalText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  bool _hasEnergyNutrient(Map<String, dynamic> payload) {
    final rows = payload['nutrients'];
    if (rows is! List) return false;
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      if (!_normalizeNutrientName(row['name']).contains('energy') &&
          !_normalizeNutrientName(row['name']).contains('calor')) {
        continue;
      }
      final amount = _numeric(row['amount']);
      if (amount != null && amount > 0) return true;
    }
    return false;
  }

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
