import '../../domain/unified_food.dart';

class OpenFoodFactsMapper {
  const OpenFoodFactsMapper();

  UnifiedFood? mapProduct({
    required String barcode,
    required Map<String, Object?> product,
  }) {
    final name = _string(product['product_name']);
    final arabicName = _string(product['product_name_ar']);
    if (name == null && arabicName == null) return null;

    final nutriments = _map(product['nutriments']);
    final nutrients = <FoodNutrient, NutrientAmount>{
      FoodNutrient.calories: _amount(nutriments, const ['energy-kcal_100g']),
      FoodNutrient.protein: _amount(nutriments, const ['proteins_100g']),
      FoodNutrient.carbohydrates: _amount(nutriments, const [
        'carbohydrates_100g',
      ]),
      FoodNutrient.fat: _amount(nutriments, const ['fat_100g']),
      FoodNutrient.fiber: _amount(nutriments, const ['fiber_100g']),
      FoodNutrient.sugar: _amount(nutriments, const ['sugars_100g']),
      FoodNutrient.sodium: _amount(nutriments, const [
        'sodium_100g',
      ], multiplier: 1000),
      FoodNutrient.potassium: _amount(nutriments, const [
        'potassium_100g',
      ], multiplier: 1000),
      FoodNutrient.calcium: _amount(nutriments, const [
        'calcium_100g',
      ], multiplier: 1000),
      FoodNutrient.magnesium: _amount(nutriments, const [
        'magnesium_100g',
      ], multiplier: 1000),
      FoodNutrient.iron: _amount(nutriments, const [
        'iron_100g',
      ], multiplier: 1000),
      FoodNutrient.vitaminC: _amount(nutriments, const [
        'vitamin-c_100g',
      ], multiplier: 1000),
    };

    final brands = _split(_string(product['brands']));
    final categories = _strings(product['categories_tags']);
    final category = categories.isEmpty
        ? _string(product['categories'])
        : categories.first.replaceFirst(RegExp(r'^[a-z]{2}:'), '');

    return UnifiedFood(
      id: 'openfoodfacts:$barcode',
      name: name ?? arabicName!,
      arabicName: arabicName,
      category: category,
      keywords: List<String>.unmodifiable(<String>{...brands, ...categories}),
      barcode: barcode,
      serving: const FoodServing(amount: 100, unit: 'g', grams: 100),
      nutrients: Map<FoodNutrient, NutrientAmount>.unmodifiable(nutrients),
      source: FoodDataSource.branded,
      sourceLabel: 'openfoodfacts',
      verified: false,
      isCustom: false,
    );
  }

  NutrientAmount _amount(
    Map<String, Object?> values,
    List<String> keys, {
    double multiplier = 1,
  }) {
    for (final key in keys) {
      final parsed = _number(values[key]);
      if (parsed != null && parsed.isFinite && parsed >= 0) {
        return NutrientAmount.known(parsed * multiplier);
      }
    }
    return const NutrientAmount.missing();
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return const <String, Object?>{};
  }

  double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> _strings(Object? value) {
    if (value is! Iterable) return const <String>[];
    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _split(String? value) => value == null
      ? const <String>[]
      : value
            .split(',')
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
}
